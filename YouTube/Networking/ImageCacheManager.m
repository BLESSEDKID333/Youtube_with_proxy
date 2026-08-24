//
//  ImageCacheManager.m
//  YouTube
//
//  Async image loader with in-memory + disk caching for iOS 6
//  Uses sync NSURLConnection on background GCD threads (reliable on iOS 6)
//

#import "ImageCacheManager.h"
#import "DebugLog.h"
#import <CommonCrypto/CommonDigest.h>

@interface ImageCacheManager ()
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) NSMutableDictionary *pendingCompletions;
@property (nonatomic, strong) dispatch_queue_t imageQueue;
@property (nonatomic, copy) NSString *diskCachePath;
@end

@implementation ImageCacheManager

+ (instancetype)sharedCache {
    static ImageCacheManager *sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[ImageCacheManager alloc] init];
    });
    return sharedCache;
}

- (id)init {
    self = [super init];
    if (self) {
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.countLimit = 100;
        _memoryCache.totalCostLimit = 50 * 1024 * 1024;
        _pendingCompletions = [NSMutableDictionary dictionary];
        _imageQueue = dispatch_queue_create("com.youtube.imagecache", DISPATCH_QUEUE_SERIAL);

        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        _diskCachePath = [cachesDir stringByAppendingPathComponent:@"YouTubeImageCache"];

        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:_diskCachePath]) {
            [fm createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return self;
}

- (UIImage *)cachedImageForURL:(NSString *)urlString {
    if (!urlString) return nil;

    UIImage *cached = [self.memoryCache objectForKey:urlString];
    if (cached) return cached;

    NSString *fileName = [self fileNameForURL:urlString];
    NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (data) {
        UIImage *image = [UIImage imageWithData:data];
        if (image) {
            [self.memoryCache setObject:image forKey:urlString cost:data.length];
            return image;
        }
    }

    return nil;
}

- (void)loadImageFromURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion {
    if (!urlString || !completion) return;

    // Check cache first (on calling thread — fast)
    UIImage *cached = [self cachedImageForURL:urlString];
    if (cached) {
        completion(cached);
        return;
    }

    @synchronized(self.pendingCompletions) {
        // If already loading, coalesce the completion
        NSMutableArray *existing = [self.pendingCompletions objectForKey:urlString];
        if (existing) {
            [existing addObject:[completion copy]];
            return;
        }
        existing = [NSMutableArray arrayWithObject:[completion copy]];
        [self.pendingCompletions setObject:existing forKey:urlString];
    }

    // Fetch on background queue using synchronous NSURLConnection
    NSString *urlCopy = [urlString copy];
    dispatch_async(self.imageQueue, ^{
        NSURL *url = [NSURL URLWithString:urlCopy];
        if (!url) {
            [self deliverResult:nil forURL:urlCopy];
            return;
        }

        NSURLRequest *request = [NSURLRequest requestWithURL:url
                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                            timeoutInterval:30.0];

        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];

        if (error || !data || [data length] == 0) {
            DLog(@"[ImageCache] FETCH FAIL: %@ — %@", urlCopy, [error localizedDescription] ?: @"empty data");
            [self deliverResult:nil forURL:urlCopy];
            return;
        }

        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        DLog(@"[ImageCache] HTTP %ld: %@ (%lu bytes)", (long)httpResp.statusCode, urlCopy, (unsigned long)data.length);

        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            DLog(@"[ImageCache] DECODE FAIL: %@ (%lu bytes)", urlCopy, (unsigned long)data.length);
            [self deliverResult:nil forURL:urlCopy];
            return;
        }

        // Cache in memory
        [self.memoryCache setObject:image forKey:urlCopy cost:data.length];

        // Save to disk
        NSString *fileName = [self fileNameForURL:urlCopy];
        NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
        [data writeToFile:filePath atomically:YES];

        DLog(@"[ImageCache] OK: %.0fx%.0f %@", image.size.width, image.size.height, urlCopy);

        [self deliverResult:image forURL:urlCopy];
    });
}

- (void)deliverResult:(UIImage *)image forURL:(NSString *)urlString {
    NSArray *completions = nil;
    @synchronized(self.pendingCompletions) {
        completions = [NSArray arrayWithArray:[self.pendingCompletions objectForKey:urlString]];
        [self.pendingCompletions removeObjectForKey:urlString];
    }

    for (void (^comp)(UIImage *) in completions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            comp(image);
        });
    }
}

- (void)cancelImageLoads {
    @synchronized(self.pendingCompletions) {
        [self.pendingCompletions removeAllObjects];
    }
}

- (void)clearCache {
    [self.memoryCache removeAllObjects];
    dispatch_async(self.imageQueue, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:self.diskCachePath error:nil];
        [fm createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
    });
}

- (NSString *)fileNameForURL:(NSString *)urlString {
    const char *str = [urlString UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", r[i]];
    }

    NSString *extension = [urlString pathExtension];
    if (extension && [extension length] > 0 && [extension length] < 6) {
        return [output stringByAppendingPathExtension:extension];
    }

    return [output stringByAppendingPathExtension:@"jpg"];
}

@end

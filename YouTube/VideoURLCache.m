#import "VideoURLCache.h"

#define CACHE_FILE @"vurl_cache.plist"
#define CACHE_TTL 1800.0

@interface VideoURLCache ()
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, strong) NSMutableDictionary *inflight;
@property (nonatomic, strong) NSString *cachePath;
@end

@implementation VideoURLCache

+ (instancetype)sharedCache {
    static VideoURLCache *instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:CACHE_FILE];
        _inflight = [NSMutableDictionary dictionary];
        [self loadCache];
    }
    return self;
}

- (void)loadCache {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        self.cache = [NSMutableDictionary dictionaryWithContentsOfFile:self.cachePath];
    }
    if (!self.cache) {
        self.cache = [NSMutableDictionary dictionary];
    }
}

- (void)saveCache {
    [self.cache writeToFile:self.cachePath atomically:YES];
}

- (NSString *)cachedURLForVideoId:(NSString *)videoId {
    NSDictionary *entry = [self.cache objectForKey:videoId];
    if (!entry) return nil;
    NSNumber *ts = [entry objectForKey:@"ts"];
    if (!ts) return nil;
    if ([[NSDate date] timeIntervalSince1970] - [ts doubleValue] > CACHE_TTL) {
        [self.cache removeObjectForKey:videoId];
        [self saveCache];
        return nil;
    }
    return [entry objectForKey:@"url"];
}

- (void)cacheURL:(NSString *)url forVideoId:(NSString *)videoId {
    if (!url || !videoId) return;
    NSDictionary *entry = @{
        @"url": url,
        @"ts": @([[NSDate date] timeIntervalSince1970])
    };
    [self.cache setObject:entry forKey:videoId];
    [self saveCache];
}

- (BOOL)isExtracting:(NSString *)videoId {
    return [[self.inflight objectForKey:videoId] boolValue];
}

- (void)setExtracting:(BOOL)extracting forVideoId:(NSString *)videoId {
    if (extracting) {
        [self.inflight setObject:@YES forKey:videoId];
    } else {
        [self.inflight removeObjectForKey:videoId];
    }
}

- (void)clearExpired {
    NSMutableArray *expired = [NSMutableArray array];
    for (NSString *vid in self.cache) {
        NSDictionary *entry = [self.cache objectForKey:vid];
        NSNumber *ts = [entry objectForKey:@"ts"];
        if (ts && [[NSDate date] timeIntervalSince1970] - [ts doubleValue] > CACHE_TTL) {
            [expired addObject:vid];
        }
    }
    for (NSString *vid in expired) {
        [self.cache removeObjectForKey:vid];
    }
    if ([expired count] > 0) [self saveCache];
}

@end

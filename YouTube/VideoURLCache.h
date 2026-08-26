#import <Foundation/Foundation.h>

@interface VideoURLCache : NSObject

+ (instancetype)sharedCache;

- (NSString *)cachedURLForVideoId:(NSString *)videoId;
- (void)cacheURL:(NSString *)url forVideoId:(NSString *)videoId;
- (BOOL)isExtracting:(NSString *)videoId;
- (void)setExtracting:(BOOL)extracting forVideoId:(NSString *)videoId;
- (void)clearExpired;

@end

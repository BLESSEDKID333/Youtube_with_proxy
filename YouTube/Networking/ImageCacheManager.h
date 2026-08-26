//
//  ImageCacheManager.h
//  YouTube
//
//  Async image loader with in-memory + disk caching for iOS 6
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImageCacheManager : NSObject

+ (instancetype)sharedCache;
- (UIImage *)cachedImageForURL:(NSString *)urlString;
- (void)loadImageFromURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion;
- (void)cancelImageLoads;
- (void)clearCache;

@end

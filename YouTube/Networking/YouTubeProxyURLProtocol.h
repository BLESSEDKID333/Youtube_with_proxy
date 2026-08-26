#import <Foundation/Foundation.h>

@interface YouTubeProxyURLProtocol : NSURLProtocol

+ (void)registerProtocol;
+ (void)unregisterProtocol;

@end

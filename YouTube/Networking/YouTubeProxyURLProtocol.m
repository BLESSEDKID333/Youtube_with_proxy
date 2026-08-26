#import "YouTubeProxyURLProtocol.h"
#import "Constants.h"
#import "DebugLog.h"

static NSString * const kYouTubeProxyURLProtocolKey = @"YouTubeProxyURLProtocol";

@interface YouTubeProxyURLProtocol () <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@end

@implementation YouTubeProxyURLProtocol

+ (void)registerProtocol {
    [NSURLProtocol registerClass:[YouTubeProxyURLProtocol class]];
}

+ (void)unregisterProtocol {
    [NSURLProtocol unregisterClass:[YouTubeProxyURLProtocol class]];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // When VPS bypass (native direct mode) is active (default), DO NOT intercept requests.
    // Allow NSURLConnection to connect directly to Google/YouTube over native TLS.
    if (VPSBypassEnabled()) {
        return NO;
    }
    if ([NSURLProtocol propertyForKey:kYouTubeProxyURLProtocolKey inRequest:request]) {
        return NO;
    }
    NSString *host = request.URL.host;
    if (!host) return NO;
    NSString *hostLower = [host lowercaseString];
    if ([hostLower hasSuffix:@"youtube.com"] ||
        [hostLower hasSuffix:@"youtube-nocookie.com"] ||
        [hostLower hasSuffix:@"googlevideo.com"] ||
        [hostLower hasSuffix:@"ytimg.com"] ||
        [hostLower hasSuffix:@"gstatic.com"] ||
        [hostLower hasSuffix:@"googleapis.com"] ||
        [hostLower hasSuffix:@"google.com"]) {
        if ([request.URL.scheme isEqualToString:@"http"] ||
            [request.URL.scheme isEqualToString:@"https"]) {
            return YES;
        }
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSURL *originalURL = self.request.URL;
    NSString *host = originalURL.host;
    NSString *path = originalURL.path;
    NSString *query = originalURL.query;
    
    NSString *proxyBase = VPSProxyBase();
    
    NSMutableString *rewrittenURLStr = [NSMutableString stringWithFormat:@"%@/ytproxy/%@%@", proxyBase, host, path];
    if (query && query.length > 0) {
        [rewrittenURLStr appendFormat:@"?%@", query];
    }
    
    NSURL *rewrittenURL = [NSURL URLWithString:rewrittenURLStr];
    if (!rewrittenURL) {
        NSError *err = [NSError errorWithDomain:@"YouTubeProxy" code:-1 userInfo:nil];
        [self.client URLProtocol:self didFailWithError:err];
        return;
    }
    
    NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:rewrittenURL
                                                                cachePolicy:self.request.cachePolicy
                                                            timeoutInterval:30];
    newRequest.HTTPMethod = self.request.HTTPMethod;
    newRequest.HTTPBody = self.request.HTTPBody;
    
    NSDictionary *origHeaders = self.request.allHTTPHeaderFields;
    NSMutableDictionary *newHeaders = [NSMutableDictionary dictionary];
    [newHeaders setObject:@"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" forKey:@"User-Agent"];
    for (NSString *key in origHeaders) {
        NSString *lk = [key lowercaseString];
        if (![lk isEqualToString:@"host"] && ![lk isEqualToString:@"accept-encoding"]) {
            [newHeaders setObject:origHeaders[key] forKey:key];
        }
    }
    newRequest.allHTTPHeaderFields = newHeaders;
    
    [NSURLProtocol setProperty:@YES forKey:kYouTubeProxyURLProtocolKey inRequest:newRequest];
    
    self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading {
    if (self.connection) {
        [self.connection cancel];
        self.connection = nil;
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = response;
    self.data = [NSMutableData data];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

@end

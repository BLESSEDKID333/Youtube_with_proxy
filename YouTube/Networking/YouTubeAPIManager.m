//
//  YouTubeAPIManager.m
//  YouTube
//
//  InnerTube Web API via NSURLConnection (original working approach)
//

#import "YouTubeAPIManager.h"
#import "Constants.h"
#import "DebugLog.h"
#import "AuthManager.h"

@interface YouTubeAPIManager () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSURLConnection *activeConnection;
@property (nonatomic, copy) NSString *currentMode; // "trending", "search", "category", "subscribe", "unsubscribe"
@property (nonatomic, copy) NSString *currentCategory;
@property (nonatomic, copy) NSString *currentQuery;
@property (nonatomic, copy) NSString *currentTargetChannelId;
@property (nonatomic, assign) NSInteger currentTag; // 0=trending, 1=search, 2=category
@end

@implementation YouTubeAPIManager

+ (instancetype)sharedManager {
    static YouTubeAPIManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[YouTubeAPIManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _receivedData = [NSMutableData data];
        DLog(@"YouTubeAPIManager init (NSURLConnection)");
    }
    return self;
}

- (void)dealloc {
    [_activeConnection cancel];
}

#pragma mark - Build InnerTube Request

- (NSURLRequest *)buildRequestWithEndpoint:(NSString *)endpoint body:(NSDictionary *)bodyDict {
    NSString *urlStr = [NSString stringWithFormat:@"%@?key=%@", endpoint, INNERTUBE_API_KEY];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:30];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:INNERTUBE_CLIENT_NAME_HEADER forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [req setValue:INNERTUBE_CLIENT_VERSION forHTTPHeaderField:@"X-YouTube-Client-Version"];

    NSString *authHeader = [[AuthManager sharedManager] sapisidHashHeader];
    if (authHeader) {
        [req setValue:authHeader forHTTPHeaderField:@"Authorization"];
        DLog(@"[Auth] Added SAPISIDHASH auth header");
    }

    NSDictionary *context = @{
        @"client": @{
            @"clientName": INNERTUBE_CLIENT_NAME,
            @"clientVersion": INNERTUBE_CLIENT_VERSION,
            @"hl": INNERTUBE_LANG,
            @"gl": INNERTUBE_COUNTRY
        }
    };

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:bodyDict];
    [payload setObject:context forKey:@"context"];

    NSError *jsonErr = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonErr];
    if (jsonErr) {
        DLog(@"JSON serialization error: %@", [jsonErr localizedDescription]);
    }
    [req setHTTPBody:jsonData];

    DLog(@"Request to: %@", urlStr);
    DLog(@"Body keys: %@", [payload allKeys]);
    return req;
}

#pragma mark - Public API

- (void)fetchTrendingFromWeb {
    if (self.isLoading) return;
    DLog(@"=== fetchTrending (search-based) ===");
    self.isLoading = YES;
    self.currentMode = @"trending";
    self.currentCategory = @"Trending";
    self.currentTag = 0;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    // browse endpoint is broken (400) — use search with trending terms
    NSArray *queries = @[@"popular music 2026", @"trending videos", @"viral videos today", @"top hits 2026", @"trending now"];
    NSUInteger idx = arc4random_uniform((uint32_t)[queries count]);
    NSString *query = [queries objectAtIndex:idx];
    DLog(@"Trending query: %@", query);

    NSDictionary *body = @{
        @"query": query
    };

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_SEARCH body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)searchFromWeb:(NSString *)query {
    [self searchFromWeb:query params:nil];
}

- (void)searchFromWeb:(NSString *)query params:(NSString *)params {
    if (self.isLoading || !query) return;
    DLog(@"=== searchFromWeb: '%@' params: '%@' ===", query, params);
    self.isLoading = YES;
    self.currentMode = @"search";
    self.currentQuery = query;
    self.currentTag = 1;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithObject:query forKey:@"query"];
    if (params && params.length > 0) {
        [body setObject:params forKey:@"params"];
    }

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_SEARCH body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)fetchCategoryFromWeb:(NSString *)categoryName {
    if (self.isLoading) return;
    DLog(@"=== fetchCategoryFromWeb: '%@' (NSURLConnection) ===", categoryName);
    self.isLoading = YES;
    self.currentMode = @"category";
    self.currentCategory = categoryName;
    self.currentTag = 2;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{
        @"query": categoryName
    };

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_SEARCH body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)fetchChannelVideos:(NSString *)channelId {
    if (self.isLoading) return;
    DLog(@"=== fetchChannelVideos: %@ ===", channelId);
    self.isLoading = YES;
    self.currentMode = @"category";
    self.currentCategory = channelId;
    self.currentTag = 3;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{
        @"browseId": channelId ?: @"",
        @"params": @"EgZ2aWRlb3M="
    };

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_BROWSE body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)likeVideo:(NSString *)videoId rating:(NSString *)rating {
    if (self.isLoading || !videoId) return;
    DLog(@"=== likeVideo: %@ rating: %@ ===", videoId, rating);
    self.isLoading = YES;
    self.currentMode = @"rate";

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSString *endpoint = INNERTUBE_LIKE;
    if ([rating isEqualToString:@"DISLIKE"]) {
        endpoint = INNERTUBE_DISLIKE;
    } else if ([rating isEqualToString:@"INDIFFERENT"]) {
        endpoint = INNERTUBE_REMOVELIKE;
    }

    NSDictionary *body = @{
        @"target": @{ @"videoId": videoId }
    };
    NSURLRequest *req = [self buildRequestWithEndpoint:endpoint body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)fetchSubscriptions {
    if (self.isLoading) return;
    DLog(@"=== fetchSubscriptions ===");
    self.isLoading = YES;
    self.currentMode = @"subscriptions";
    self.currentCategory = @"Subscriptions";
    self.currentTag = 4;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{
        @"browseId": @"FEsubscriptions"
    };

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_BROWSE body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)subscribeToChannel:(NSString *)channelId {
    if (self.isLoading) return;
    DLog(@"=== subscribeToChannel: %@ ===", channelId);
    self.isLoading = YES;
    self.currentMode = @"subscribe";
    self.currentTargetChannelId = channelId;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{@"channelIds": @[channelId]};
    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_SUBSCRIBE body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)unsubscribeFromChannel:(NSString *)channelId {
    if (self.isLoading) return;
    DLog(@"=== unsubscribeFromChannel: %@ ===", channelId);
    self.isLoading = YES;
    self.currentMode = @"unsubscribe";
    self.currentTargetChannelId = channelId;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{@"channelIds": @[channelId]};
    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_UNSUBSCRIBE body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)cancelAllRequests {
    DLog(@"cancelAllRequests");
    [self.activeConnection cancel];
    self.activeConnection = nil;
    self.isLoading = NO;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    DLog(@"Connection FAILED: %@", [error localizedDescription]);
    self.isLoading = NO;
    self.activeConnection = nil;

    if ([self.delegate respondsToSelector:@selector(apiManager:didFailWithError:)]) {
        [self.delegate apiManager:self didFailWithError:error];
    }
    if ([self.delegate respondsToSelector:@selector(apiManagerDidFinishLoading:)]) {
        [self.delegate apiManagerDidFinishLoading:self];
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        return YES;
    }
    return [connection.originalRequest.URL.scheme isEqualToString:@"https"];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
             forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
    DLog(@"Response: %ld", (long)httpResp.statusCode);
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    DLog(@"Connection finished, data length=%lu", (unsigned long)[self.receivedData length]);
    self.activeConnection = nil;

    if ([self.receivedData length] == 0) {
        DLog(@"Empty response!");
        [self reportError:-1 msg:@"Empty response from server"];
        return;
    }

    NSError *jsonErr = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:self.receivedData options:0 error:&jsonErr];
    if (jsonErr || !json) {
        NSString *rawStr = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
        DLog(@"JSON parse error: %@, raw length=%lu", [jsonErr localizedDescription], (unsigned long)[self.receivedData length]);
        if (rawStr) DLog(@"Raw (first 500): %@", [rawStr substringToIndex:MIN(500, [rawStr length])]);
        [self reportError:-2 msg:@"JSON parse error"];
        return;
    }

    self.lastResponseJSON = json;
    DLog(@"JSON keys: %@", [json allKeys]);

    // Check for API-level error
    id apiError = [json objectForKey:@"error"];
    if (apiError && [apiError isKindOfClass:[NSDictionary class]]) {
        DLog(@"API returned error: %@", apiError);
        [self reportError:-3 msg:[[apiError objectForKey:@"message"] ?: @"API Error" description]];
        return;
    }

    NSArray *renderers = [self findVideoRenderersInObject:json];
    DLog(@"Found %lu video renderers", (unsigned long)[renderers count]);

    NSMutableArray *videos = [NSMutableArray array];
    for (NSDictionary *renderer in renderers) {
        YTVideo *video = [YTVideo videoWithWebRenderer:renderer];
        if (video && video.videoId) {
            BOOL exists = NO;
            for (YTVideo *e in videos) {
                if ([e.videoId isEqualToString:video.videoId]) { exists = YES; break; }
            }
            if (!exists) {
                [videos addObject:video];
            }
        }
    }

    DLog(@"Unique videos: %lu", (unsigned long)[videos count]);

    self.nextPageToken = [self findContinuationTokenInObject:json];

    if ([self.delegate respondsToSelector:@selector(apiManagerDidFinishLoading:)]) {
        [self.delegate apiManagerDidFinishLoading:self];
    }

    if ([self.currentMode isEqualToString:@"subscribe"] || [self.currentMode isEqualToString:@"unsubscribe"]) {
        BOOL subscribed = [self.currentMode isEqualToString:@"subscribe"];
        id errorObj = [json objectForKey:@"error"];
        if (errorObj) {
            DLog(@"Subscribe/unsubscribe failed: %@", errorObj);
            subscribed = NO;
        }
        if ([self.delegate respondsToSelector:@selector(apiManager:didSubscribeToChannel:subscribed:)]) {
            [self.delegate apiManager:self didSubscribeToChannel:self.currentTargetChannelId subscribed:subscribed];
        }
    } else if ([self.currentMode isEqualToString:@"trending"] || [self.currentMode isEqualToString:@"category"] || [self.currentMode isEqualToString:@"subscriptions"]) {
        if ([self.delegate respondsToSelector:@selector(apiManager:didReceiveVideos:forCategory:)]) {
            [self.delegate apiManager:self didReceiveVideos:videos
                          forCategory:self.currentCategory ?: self.currentMode];
        }
    } else if ([self.currentMode isEqualToString:@"search"]) {
        if ([self.delegate respondsToSelector:@selector(apiManager:didReceiveSearchResults:nextPageToken:)]) {
            [self.delegate apiManager:self didReceiveSearchResults:videos
                        nextPageToken:self.nextPageToken];
        }
    }

    self.isLoading = NO;
}

#pragma mark - Error Helper

- (void)reportError:(NSInteger)code msg:(NSString *)msg {
    DLog(@"ERROR [%ld]: %@", (long)code, msg);
    NSError *err = [NSError errorWithDomain:@"YouTubeAPI" code:code
                                    userInfo:@{NSLocalizedDescriptionKey: msg}];
    if ([self.delegate respondsToSelector:@selector(apiManagerDidFinishLoading:)]) {
        [self.delegate apiManagerDidFinishLoading:self];
    }
    if ([self.delegate respondsToSelector:@selector(apiManager:didFailWithError:)]) {
        [self.delegate apiManager:self didFailWithError:err];
    }
    self.isLoading = NO;
}

#pragma mark - Recursive Video Renderer Finder

- (NSMutableArray *)findVideoRenderersInObject:(id)obj {
    NSMutableArray *results = [NSMutableArray array];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;

        // Direct videoRenderer
        id vr = [dict objectForKey:@"videoRenderer"];
        if (vr && [vr isKindOfClass:[NSDictionary class]]) {
            [results addObject:vr];
        }

        // Channel renderer
        id chr = [dict objectForKey:@"channelRenderer"];
        if (chr && [chr isKindOfClass:[NSDictionary class]]) {
            [results addObject:chr];
        }

        // Grid video renderer
        id gvr = [dict objectForKey:@"gridVideoRenderer"];
        if (gvr && [gvr isKindOfClass:[NSDictionary class]]) {
            [results addObject:gvr];
        }

        // Compact video renderer (search results)
        id cvr = [dict objectForKey:@"compactVideoRenderer"];
        if (cvr && [cvr isKindOfClass:[NSDictionary class]]) {
            [results addObject:cvr];
        }

        // Reel item
        id ris = [dict objectForKey:@"reelItemRenderer"];
        if (ris && [ris isKindOfClass:[NSDictionary class]]) {
            [results addObject:ris];
        }

        // Rich item
        id richItem = [dict objectForKey:@"richItemRenderer"];
        if (richItem && [richItem isKindOfClass:[NSDictionary class]]) {
            id content = [(NSDictionary *)richItem objectForKey:@"content"];
            if (content && [content isKindOfClass:[NSDictionary class]]) {
                id vr2 = [(NSDictionary *)content objectForKey:@"videoRenderer"];
                if (vr2 && [vr2 isKindOfClass:[NSDictionary class]]) {
                    [results addObject:vr2];
                }
            }
        }

        // Shelves
        id shelfRenderer = [dict objectForKey:@"shelfRenderer"];
        if (shelfRenderer && [shelfRenderer isKindOfClass:[NSDictionary class]]) {
            id content = [(NSDictionary *)shelfRenderer objectForKey:@"content"];
            if (content) {
                [results addObjectsFromArray:[self findVideoRenderersInObject:content]];
            }
        }

        // Item section renderer
        id isr = [dict objectForKey:@"itemSectionRenderer"];
        if (isr && [isr isKindOfClass:[NSDictionary class]]) {
            id contents = [(NSDictionary *)isr objectForKey:@"contents"];
            if (contents) {
                [results addObjectsFromArray:[self findVideoRenderersInObject:contents]];
            }
        }

        // Section list renderer
        id slr = [dict objectForKey:@"sectionListRenderer"];
        if (slr && [slr isKindOfClass:[NSDictionary class]]) {
            id contents = [(NSDictionary *)slr objectForKey:@"contents"];
            if (contents) {
                [results addObjectsFromArray:[self findVideoRenderersInObject:contents]];
            }
        }

        // Rich grid renderer (trending)
        id rgr = [dict objectForKey:@"richGridRenderer"];
        if (rgr && [rgr isKindOfClass:[NSDictionary class]]) {
            id contents = [(NSDictionary *)rgr objectForKey:@"contents"];
            if (contents) {
                [results addObjectsFromArray:[self findVideoRenderersInObject:contents]];
            }
        }

        // Tab content
        id tcr = [dict objectForKey:@"tabRenderer"];
        if (tcr && [tcr isKindOfClass:[NSDictionary class]]) {
            id content = [(NSDictionary *)tcr objectForKey:@"content"];
            if (content) {
                [results addObjectsFromArray:[self findVideoRenderersInObject:content]];
            }
        }

        // Recurse all values
        for (id value in [dict allValues]) {
            [results addObjectsFromArray:[self findVideoRenderersInObject:value]];
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)obj) {
            [results addObjectsFromArray:[self findVideoRenderersInObject:item]];
        }
    }
    return results;
}

#pragma mark - Recursive Continuation Token Finder

- (NSString *)findContinuationTokenInObject:(id)obj {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;

        id contItem = [dict objectForKey:@"continuationItemRenderer"];
        if (contItem && [contItem isKindOfClass:[NSDictionary class]]) {
            id contEndpoint = [(NSDictionary *)contItem objectForKey:@"continuationEndpoint"];
            if ([contEndpoint isKindOfClass:[NSDictionary class]]) {
                id contCmd = [(NSDictionary *)contEndpoint objectForKey:@"continuationCommand"];
                if ([contCmd isKindOfClass:[NSDictionary class]]) {
                    NSString *token = [(NSDictionary *)contCmd objectForKey:@"token"];
                    if (token && [token isKindOfClass:[NSString class]]) return token;
                }
            }
        }

        for (id value in [dict allValues]) {
            NSString *found = [self findContinuationTokenInObject:value];
            if (found) return found;
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)obj) {
            NSString *found = [self findContinuationTokenInObject:item];
            if (found) return found;
        }
    }
    return nil;
}

@end

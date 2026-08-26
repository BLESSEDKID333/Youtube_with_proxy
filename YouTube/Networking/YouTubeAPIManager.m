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
#import "TLSTrustManager.h"

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
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];

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
    DLog(@"=== fetchTrending ===");
    self.isLoading = YES;
    self.currentMode = @"trending";
    self.currentCategory = @"Trending";
    self.currentTag = 0;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body;
    NSString *endpoint;
    if ([[AuthManager sharedManager] isLoggedIn]) {
        endpoint = INNERTUBE_BROWSE;
        body = @{@"browseId": @"FEwhat_to_watch"};
    } else {
        endpoint = INNERTUBE_SEARCH;
        NSArray *queries = @[@"popular music 2026", @"trending videos", @"viral videos today", @"top hits 2026"];
        NSUInteger idx = arc4random_uniform((uint32_t)[queries count]);
        body = @{@"query": [queries objectAtIndex:idx]};
    }

    NSURLRequest *req = [self buildRequestWithEndpoint:endpoint body:body];
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
    if (params) {
        [body setObject:params forKey:@"params"];
    }

    NSURLRequest *req = [self buildRequestWithEndpoint:INNERTUBE_SEARCH body:body];
    self.receivedData = [NSMutableData data];
    self.activeConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
}

- (void)fetchCategoryFromWeb:(NSString *)categoryName {
    [self fetchCategoryVideosFromWeb:categoryName];
}

- (void)fetchCategoryVideosFromWeb:(NSString *)categoryId {
    if (self.isLoading) return;
    DLog(@"=== fetchCategoryVideos: %@ ===", categoryId);
    self.isLoading = YES;
    self.currentMode = @"category";
    self.currentCategory = categoryId;
    self.currentTag = 2;
    self.nextPageToken = nil;
    self.prevPageToken = nil;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *categoryQueries = @{
        @"10": @"music videos hits",
        @"20": @"gaming gameplay 2026",
        @"1": @"movie trailers",
        @"25": @"news today",
        @"17": @"sports highlights",
        @"27": @"education science",
        @"23": @"comedy funny",
        @"24": @"entertainment shows",
        @"28": @"technology tech reviews",
        @"26": @"politics"
    };

    NSString *query = [categoryQueries objectForKey:categoryId] ?: @"popular videos";
    NSDictionary *body = @{
        @"query": query
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

- (void)fetchShortsFromWeb {
    if (self.isLoading) return;
    DLog(@"=== fetchShortsFromWeb ===");
    self.isLoading = YES;
    self.currentMode = @"shorts";
    self.currentCategory = @"Shorts";
    self.currentTag = 5;

    if ([self.delegate respondsToSelector:@selector(apiManagerDidStartLoading:)]) {
        [self.delegate apiManagerDidStartLoading:self];
    }

    NSDictionary *body = @{
        @"browseId": @"FEshorts"
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
    if ([[TLSTrustManager sharedManager] handleAuthenticationChallenge:challenge forConnection:connection]) {
        return;
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
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
    } else if ([self.currentMode isEqualToString:@"trending"] || [self.currentMode isEqualToString:@"category"] || [self.currentMode isEqualToString:@"subscriptions"] || [self.currentMode isEqualToString:@"shorts"]) {
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

#pragma mark - Non-recursive Video Renderer Finder

- (NSMutableArray *)findVideoRenderersInObject:(id)obj {
    NSMutableArray *results = [NSMutableArray array];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;

        // Direct videoRenderer
        id vr = [dict objectForKey:@"videoRenderer"];
        if (vr && [vr isKindOfClass:[NSDictionary class]]) {
            [results addObject:vr];
            return results;
        }

        // Channel renderer
        id chr = [dict objectForKey:@"channelRenderer"];
        if (chr && [chr isKindOfClass:[NSDictionary class]]) {
            [results addObject:chr];
            return results;
        }

        // Grid video renderer
        id gvr = [dict objectForKey:@"gridVideoRenderer"];
        if (gvr && [gvr isKindOfClass:[NSDictionary class]]) {
            [results addObject:gvr];
            return results;
        }

        // Compact video renderer
        id cvr = [dict objectForKey:@"compactVideoRenderer"];
        if (cvr && [cvr isKindOfClass:[NSDictionary class]]) {
            [results addObject:cvr];
            return results;
        }

        // Reel item renderer
        id ris = [dict objectForKey:@"reelItemRenderer"];
        if (ris && [ris isKindOfClass:[NSDictionary class]]) {
            [results addObject:ris];
            return results;
        }

        // Lockup view model
        id lvm = [dict objectForKey:@"lockupViewModel"];
        if (lvm && [lvm isKindOfClass:[NSDictionary class]]) {
            [results addObject:lvm];
            return results;
        }

        // Recurse all dictionary values
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

- (NSString *)findContinuationTokenInObject:(id)obj {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        id token = [dict objectForKey:@"continuation"];
        if (token && [token isKindOfClass:[NSString class]]) return token;

        id contEndpoint = [dict objectForKey:@"continuationEndpoint"];
        if (contEndpoint && [contEndpoint isKindOfClass:[NSDictionary class]]) {
            id cCommand = [contEndpoint objectForKey:@"continuationCommand"];
            if (cCommand && [cCommand isKindOfClass:[NSDictionary class]]) {
                id token2 = [cCommand objectForKey:@"token"];
                if (token2 && [token2 isKindOfClass:[NSString class]]) return token2;
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

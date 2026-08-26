//
//  LocalStreamProxy.m
//  YouTube
//

#import "LocalStreamProxy.h"
#import "TLSTrustManager.h"
#import "Constants.h"
#import "DebugLog.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <errno.h>

// Android UA — googlevideo serves progressive itag 18 to this without extra checks.
static NSString * const kStreamUA = @"com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip";

#pragma mark - StreamPipe (one upstream fetch relayed to one client socket)

@interface StreamPipe : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, assign) int clientFd;
@property (nonatomic, copy)   NSString *remoteURL;
@property (nonatomic, copy)   NSString *rangeHeader;
@property (nonatomic, assign) BOOL done;
@property (nonatomic, assign) BOOL headSent;
@property (nonatomic, assign) BOOL clientGone;
@property (nonatomic, strong) NSURLConnection *conn;
@end

static BOOL SendAll(int fd, const uint8_t *bytes, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = send(fd, bytes + sent, len - sent, 0);
        if (n <= 0) {
            if (n < 0 && errno == EINTR) continue;
            return NO;
        }
        sent += (size_t)n;
    }
    return YES;
}

@implementation StreamPipe

- (void)run {
    NSURL *url = [NSURL URLWithString:self.remoteURL];
    if (!url) { [self finishNow]; return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                  timeoutInterval:60];
    [req setValue:kStreamUA forHTTPHeaderField:@"User-Agent"];
    if (self.rangeHeader.length > 0) {
        // rangeHeader looks like "Range: bytes=0-"; split into field/value.
        NSRange colon = [self.rangeHeader rangeOfString:@":"];
        if (colon.location != NSNotFound) {
            NSString *v = [[self.rangeHeader substringFromIndex:colon.location + 1]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [req setValue:v forHTTPHeaderField:@"Range"];
        }
    }

    self.conn = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [self.conn scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.conn start];

    // Drive this thread's runloop until the transfer finishes or the client drops.
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (!self.done && [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]]) {
        if (self.done) break;
    }
}

- (void)finishNow {
    if (self.done) return;
    self.done = YES;
    [self.conn cancel];
    self.conn = nil;
}

#pragma mark NSURLConnection delegate

- (BOOL)connection:(NSURLConnection *)c canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)ps {
    return [ps.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)c willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch {
    if ([[TLSTrustManager sharedManager] handleAuthenticationChallenge:ch forConnection:c]) return;
    [ch.sender continueWithoutCredentialForAuthenticationChallenge:ch];
}

- (void)connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
    NSInteger status = [http respondsToSelector:@selector(statusCode)] ? http.statusCode : 200;

    NSString *ctype = response.MIMEType.length ? response.MIMEType : @"video/mp4";
    long long clen = response.expectedContentLength;
    NSString *contentRange = nil;
    NSString *acceptRanges = @"bytes";
    if ([http respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *h = http.allHeaderFields;
        contentRange = [h objectForKey:@"Content-Range"] ?: [h objectForKey:@"content-range"];
    }

    NSMutableString *head = [NSMutableString stringWithFormat:@"HTTP/1.1 %ld %@\r\n",
                             (long)status, (status == 206 ? @"Partial Content" : @"OK")];
    [head appendFormat:@"Content-Type: %@\r\n", ctype];
    if (clen > 0) [head appendFormat:@"Content-Length: %lld\r\n", clen];
    if (contentRange) [head appendFormat:@"Content-Range: %@\r\n", contentRange];
    [head appendFormat:@"Accept-Ranges: %@\r\n", acceptRanges];
    [head appendString:@"Connection: close\r\n\r\n"];

    NSData *headData = [head dataUsingEncoding:NSISOLatin1StringEncoding];
    if (!SendAll(self.clientFd, headData.bytes, headData.length)) {
        self.clientGone = YES;
        [self finishNow];
        return;
    }
    self.headSent = YES;
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)data {
    if (self.done) return;
    // Blocking send applies natural backpressure: if the player isn't draining,
    // send() blocks here and the connection stops pulling more bytes.
    if (!SendAll(self.clientFd, data.bytes, data.length)) {
        self.clientGone = YES;   // player closed the socket (seek / new video)
        [self finishNow];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)c {
    [self finishNow];
}

- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)error {
    DLog(@"[Proxy] upstream fail: %@", [error localizedDescription]);
    if (!self.headSent && !self.clientGone) {
        const char *bad = "HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n";
        SendAll(self.clientFd, (const uint8_t *)bad, strlen(bad));
    }
    [self finishNow];
}

@end


#pragma mark - LocalStreamProxy

@interface LocalStreamProxy () {
    int _listenFd;
    uint16_t _port;
    BOOL _started;
    NSUInteger _counter;
}
@property (nonatomic, strong) NSMutableDictionary *routes; // token -> remote URL
@end

@implementation LocalStreamProxy

+ (instancetype)sharedProxy {
    static LocalStreamProxy *p = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [[LocalStreamProxy alloc] init]; });
    return p;
}

- (id)init {
    self = [super init];
    if (self) {
        _routes = [NSMutableDictionary dictionary];
        _listenFd = -1;
    }
    return self;
}

- (BOOL)startIfNeeded {
    @synchronized(self) {
        if (_started) return YES;

        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) { DLog(@"[Proxy] socket() failed"); return NO; }

        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        addr.sin_port = 0; // ephemeral

        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) { close(fd); DLog(@"[Proxy] bind failed"); return NO; }
        if (listen(fd, 8) < 0) { close(fd); DLog(@"[Proxy] listen failed"); return NO; }

        struct sockaddr_in bound;
        socklen_t len = sizeof(bound);
        if (getsockname(fd, (struct sockaddr *)&bound, &len) < 0) { close(fd); return NO; }
        _port = ntohs(bound.sin_port);
        _listenFd = fd;
        _started = YES;

        NSThread *t = [[NSThread alloc] initWithTarget:self selector:@selector(acceptLoop) object:nil];
        [t setStackSize:512 * 1024];
        [t start];

        DLog(@"[Proxy] listening on 127.0.0.1:%u", _port);
        return YES;
    }
}

- (NSString *)localURLForRemoteURL:(NSString *)remoteURL {
    if (![self startIfNeeded]) return remoteURL;
    NSString *token;
    @synchronized(self) {
        _counter++;
        token = [NSString stringWithFormat:@"s%lu", (unsigned long)_counter];
        [self.routes setObject:remoteURL forKey:token];
    }
    return [NSString stringWithFormat:@"http://127.0.0.1:%u/%@.mp4", _port, token];
}

- (void)acceptLoop {
    while (YES) {
        int client = accept(_listenFd, NULL, NULL);
        if (client < 0) {
            if (errno == EINTR) continue;
            break;
        }
        int yes = 1;
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
        NSThread *t = [[NSThread alloc] initWithTarget:self selector:@selector(handleConnection:)
                                                object:[NSNumber numberWithInt:client]];
        [t setStackSize:512 * 1024];
        [t start];
    }
}

- (void)handleConnection:(NSNumber *)num {
    int clientFd = [num intValue];
    @autoreleasepool {
        NSString *head = [self readRequestHead:clientFd];
        if (!head) { close(clientFd); return; }

        NSArray *lines = [head componentsSeparatedByString:@"\r\n"];
        NSString *requestLine = lines.count ? [lines objectAtIndex:0] : nil;
        NSArray *parts = [requestLine componentsSeparatedByString:@" "];
        if (parts.count < 2) {
            const char *bad = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n";
            SendAll(clientFd, (const uint8_t *)bad, strlen(bad));
            close(clientFd);
            return;
        }

        NSString *token = [parts objectAtIndex:1];
        if ([token hasPrefix:@"/"]) token = [token substringFromIndex:1];
        NSRange dot = [token rangeOfString:@"."];
        if (dot.location != NSNotFound) token = [token substringToIndex:dot.location];
        NSRange q = [token rangeOfString:@"?"];
        if (q.location != NSNotFound) token = [token substringToIndex:q.location];

        NSString *remote = nil;
        @synchronized(self) { remote = [self.routes objectForKey:token]; }
        if (!remote) {
            const char *nf = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n";
            SendAll(clientFd, (const uint8_t *)nf, strlen(nf));
            close(clientFd);
            return;
        }

        NSString *rangeHeader = nil;
        for (NSUInteger i = 1; i < lines.count; i++) {
            NSString *line = [lines objectAtIndex:i];
            if ([[line lowercaseString] hasPrefix:@"range:"]) { rangeHeader = line; break; }
        }

        StreamPipe *pipe = [[StreamPipe alloc] init];
        pipe.clientFd = clientFd;
        pipe.remoteURL = remote;
        pipe.rangeHeader = rangeHeader;
        [pipe run];   // blocks this thread's runloop until finished
    }
    close(clientFd);
}

- (NSString *)readRequestHead:(int)fd {
    NSMutableData *data = [NSMutableData data];
    uint8_t buf[2048];
    NSData *terminator = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    while ([data rangeOfData:terminator options:0 range:NSMakeRange(0, data.length)].location == NSNotFound) {
        ssize_t n = recv(fd, buf, sizeof(buf), 0);
        if (n <= 0) return data.length ? [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] : nil;
        [data appendBytes:buf length:(NSUInteger)n];
        if (data.length > 16 * 1024) break;
    }
    return [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

@end

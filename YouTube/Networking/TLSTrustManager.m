//
//  TLSTrustManager.m
//  YouTube
//

#import "TLSTrustManager.h"
#import "DebugLog.h"
#import <Security/Security.h>

@interface TLSTrustManager ()
@property (nonatomic, strong) NSArray *anchors; // array of id (SecCertificateRef)
@end

@implementation TLSTrustManager

+ (instancetype)sharedManager {
    static TLSTrustManager *mgr = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mgr = [[TLSTrustManager alloc] init]; });
    return mgr;
}

- (id)init {
    self = [super init];
    if (self) {
        [self loadAnchors];
    }
    return self;
}

- (void)loadAnchors {
    NSMutableArray *certs = [NSMutableArray array];

    // Certs/ folder is copied verbatim into the app bundle by the Makefile.
    NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"cer" inDirectory:@"Certs"];
    if (paths.count == 0) {
        // Fallback: flat resource root (in case the bundler flattened it)
        paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"cer" inDirectory:nil];
    }

    for (NSString *path in paths) {
        NSData *der = [NSData dataWithContentsOfFile:path];
        if (!der) continue;
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (cert) {
            [certs addObject:(__bridge_transfer id)cert];
        }
    }

    _anchors = certs;
    DLog(@"[TLSTrust] loaded %lu modern root anchors", (unsigned long)certs.count);
}

- (BOOL)hasModernRoots { return self.anchors.count > 0; }
- (NSUInteger)rootCount { return self.anchors.count; }

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forHost:(NSString *)host {
    if (!serverTrust) return NO;

    // Anchor against our bundled modern roots IN ADDITION to whatever the OS ships.
    if (self.anchors.count > 0) {
        SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)self.anchors);
        SecTrustSetAnchorCertificatesOnly(serverTrust, false); // also allow system anchors
    }

    SecTrustResultType result = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(serverTrust, &result);
    if (status != errSecSuccess) {
        DLog(@"[TLSTrust] SecTrustEvaluate error %d for %@", (int)status, host);
        return NO;
    }

    BOOL ok = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    DLog(@"[TLSTrust] %@ trust result=%u -> %@", host, (unsigned)result, ok ? @"OK" : @"REJECT");
    return ok;
}

- (BOOL)handleAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                        forConnection:(NSURLConnection *)connection {
    NSString *method = challenge.protectionSpace.authenticationMethod;
    if (![method isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        return NO; // not ours — let default handling proceed
    }

    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    NSString *host = challenge.protectionSpace.host;

    if ([self evaluateServerTrust:serverTrust forHost:host]) {
        NSURLCredential *cred = [NSURLCredential credentialForTrust:serverTrust];
        [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender cancelAuthenticationChallenge:challenge];
    }
    return YES;
}

@end

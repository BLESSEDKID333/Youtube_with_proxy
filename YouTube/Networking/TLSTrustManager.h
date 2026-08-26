//
//  TLSTrustManager.h
//  YouTube
//
//  Native TLS trust evaluation for iOS 6 using modern root CAs bundled
//  inside the app (extracted from tlsroot.litten.ca). Combined with the
//  TLSFix tweak (modern OpenSSL handshake/ciphers), this lets the client
//  talk to YouTube / Google directly, with no VPS proxy.
//

#import <Foundation/Foundation.h>

@interface TLSTrustManager : NSObject

+ (instancetype)sharedManager;

// YES if the bundled modern root store loaded successfully.
@property (nonatomic, readonly) BOOL hasModernRoots;
@property (nonatomic, readonly) NSUInteger rootCount;

// Handle an NSURLConnection server-trust challenge. Returns YES if it fully
// handled the challenge (accepted or rejected); NO to let the default logic run.
- (BOOL)handleAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                        forConnection:(NSURLConnection *)connection;

@end

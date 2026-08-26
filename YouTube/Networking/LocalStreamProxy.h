//
//  LocalStreamProxy.h
//  YouTube
//
//  A tiny in-app HTTP proxy on 127.0.0.1. MPMoviePlayerController's media fetch
//  runs inside mediaserverd, which TLSFix does NOT inject into — so a direct
//  https://…googlevideo.com URL fails there (the classic "white rectangle").
//
//  This proxy accepts the player's plain-HTTP request on localhost, re-fetches
//  the real HTTPS stream from *inside the app process* (where TLSFix + the
//  bundled modern roots make TLS work), and relays the bytes back — forwarding
//  Range headers so seeking works. Same trick OldPipe uses (it relays via
//  libcurl; we relay via NSURLConnection, which TLSFix already covers).
//

#import <Foundation/Foundation.h>

@interface LocalStreamProxy : NSObject

+ (instancetype)sharedProxy;

// Starts the listener if it isn't already running. Returns NO on failure.
- (BOOL)startIfNeeded;

// Registers a remote HTTPS stream URL and returns a local http://127.0.0.1:port/<token>
// URL to hand to MPMoviePlayerController. Returns the original URL if start failed.
- (NSString *)localURLForRemoteURL:(NSString *)remoteURL;

@end

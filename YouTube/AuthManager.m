#import "AuthManager.h"
#import "DebugLog.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

NSString *const AuthStateChangedNotification = @"AuthStateChangedNotification";

static NSString *const kAuthSAPISID = @"SAPISID";
static NSString *const kAuthUsernameKey = @"auth_username";
static NSString *const kAuthChannelIdKey = @"auth_channel_id";
static NSString *const kDeviceUUIDKey = @"yt_device_uuid";

@interface AuthManager ()
@property (nonatomic, assign, readwrite) BOOL loggedIn;
@property (nonatomic, copy, readwrite) NSString *userName;
@property (nonatomic, copy, readwrite) NSString *channelId;
@end

@implementation AuthManager

- (NSString *)deviceUUID {
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:kDeviceUUIDKey];
    if (!uuid) {
        uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        if (!uuid) {
            CFUUIDRef cfuuid = CFUUIDCreate(kCFAllocatorDefault);
            uuid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, cfuuid);
            CFRelease(cfuuid);
        }
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:kDeviceUUIDKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return uuid;
}

+ (instancetype)sharedManager {
    static AuthManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [[AuthManager alloc] init];
    });
    return m;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self checkLoginState];
    }
    return self;
}

- (void)checkLoginState {
    NSString *sapisid = [self sapisidCookie];
    if (sapisid.length > 0) {
        self.loggedIn = YES;
        self.userName = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthUsernameKey] ?: @"User";
        self.channelId = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthChannelIdKey] ?: @"";
        DLog(@"[Auth] Logged in, SAPISID present");
    } else {
        self.loggedIn = NO;
        self.userName = nil;
        self.channelId = nil;
        DLog(@"[Auth] Not logged in");
    }
}

- (void)saveSAPISID:(NSString *)sapisid {
    if (sapisid.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:sapisid forKey:kAuthSAPISID];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.loggedIn = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:AuthStateChangedNotification object:nil];
    }
}

- (NSString *)sapisidCookie {
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthSAPISID];
    if (stored.length > 0) return stored;

    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [storage cookies];
    for (NSHTTPCookie *c in cookies) {
        if ([[c.name uppercaseString] isEqualToString:@"SAPISID"] ||
            [[c.name uppercaseString] isEqualToString:@"__SECURE-3PSAPISID"]) {
            if (c.value.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:c.value forKey:kAuthSAPISID];
                [[NSUserDefaults standardUserDefaults] synchronize];
                return c.value;
            }
        }
    }
    return nil;
}

- (NSString *)sapisidHashHeader {
    NSString *sapisid = [self sapisidCookie];
    if (!sapisid) return nil;

    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", ts];
    NSString *raw = [NSString stringWithFormat:@"%@ %@", timestamp, sapisid];

    const char *cStr = [raw UTF8String];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cStr, (CC_LONG)strlen(cStr), digest);

    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }

    return [NSString stringWithFormat:@"SAPISIDHASH %@_%@", timestamp, hash];
}

- (void)saveUserInfo:(NSString *)name channelId:(NSString *)channelId {
    self.userName = name;
    self.channelId = channelId;
    [[NSUserDefaults standardUserDefaults] setObject:name ?: @"" forKey:kAuthUsernameKey];
    [[NSUserDefaults standardUserDefaults] setObject:channelId ?: @"" forKey:kAuthChannelIdKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)logout {
    self.loggedIn = NO;
    self.userName = nil;
    self.channelId = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthSAPISID];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthUsernameKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthChannelIdKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *c in [storage cookies]) {
        if ([[c.domain lowercaseString] rangeOfString:@"google"].length > 0 ||
            [[c.domain lowercaseString] rangeOfString:@"youtube"].length > 0) {
            [storage deleteCookie:c];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:AuthStateChangedNotification object:nil];
    DLog(@"[Auth] Logged out");
}

@end

#import "AuthManager.h"
#import "DebugLog.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

NSString *const AuthStateChangedNotification = @"AuthStateChangedNotification";

static NSString *const kAuthSAPISID = @"SAPISID";
static NSString *const kAuthUsernameKey = @"auth_username";
static NSString *const kAuthUserEmailKey = @"auth_user_email";
static NSString *const kAuthChannelIdKey = @"auth_channel_id";
static NSString *const kAuthAvatarUrlKey = @"auth_avatar_url";
static NSString *const kDeviceUUIDKey = @"yt_device_uuid";

@interface AuthManager ()
@property (nonatomic, assign, readwrite) BOOL loggedIn;
@property (nonatomic, copy, readwrite) NSString *userName;
@property (nonatomic, copy, readwrite) NSString *userEmail;
@property (nonatomic, copy, readwrite) NSString *channelId;
@property (nonatomic, copy, readwrite) NSString *avatarUrl;
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
        self.userName = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthUsernameKey] ?: @"Account";
        self.userEmail = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthUserEmailKey] ?: @"";
        self.channelId = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthChannelIdKey] ?: @"";
        self.avatarUrl = [[NSUserDefaults standardUserDefaults] stringForKey:kAuthAvatarUrlKey] ?: @"";
        DLog(@"[Auth] Logged in: %@ (%@)", self.userName, self.userEmail);
    } else {
        self.loggedIn = NO;
        self.userName = nil;
        self.userEmail = nil;
        self.channelId = nil;
        self.avatarUrl = nil;
        DLog(@"[Auth] Not logged in");
    }
}

- (void)saveSAPISID:(NSString *)sapisid {
    if (sapisid.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:sapisid forKey:kAuthSAPISID];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.loggedIn = YES;
        [self fetchAccountProfile];
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
    if (!sapisid || sapisid.length == 0) return nil;

    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", ts];
    NSString *raw = [NSString stringWithFormat:@"%@ %@ https://www.youtube.com", timestamp, sapisid];

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
    [self saveUserInfo:name email:nil channelId:channelId avatarUrl:nil];
}

- (void)saveUserInfo:(NSString *)name email:(NSString *)email channelId:(NSString *)channelId avatarUrl:(NSString *)avatarUrl {
    if (name) self.userName = name;
    if (email) self.userEmail = email;
    if (channelId) self.channelId = channelId;
    if (avatarUrl) self.avatarUrl = avatarUrl;

    [[NSUserDefaults standardUserDefaults] setObject:self.userName ?: @"" forKey:kAuthUsernameKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.userEmail ?: @"" forKey:kAuthUserEmailKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.channelId ?: @"" forKey:kAuthChannelIdKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.avatarUrl ?: @"" forKey:kAuthAvatarUrlKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:AuthStateChangedNotification object:nil];
}

- (void)fetchAccountProfile {
    if (![self sapisidCookie]) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *urlStr = @"http://192.144.13.102/youtubei/v1/account/account_menu?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                         timeoutInterval:10];
        [req setHTTPMethod:@"POST"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:@"1" forHTTPHeaderField:@"X-YouTube-Client-Name"];
        [req setValue:@"2.20260727.01.00" forHTTPHeaderField:@"X-YouTube-Client-Version"];
        
        NSString *authHeader = [self sapisidHashHeader];
        if (authHeader) [req setValue:authHeader forHTTPHeaderField:@"Authorization"];
        
        NSDictionary *payload = @{@"context": @{@"client": @{@"clientName": @"WEB", @"clientVersion": @"2.20260727.01.00"}}};
        [req setHTTPBody:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]];

        NSHTTPURLResponse *resp = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:nil];
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            NSString *foundEmail = nil;
            NSString *foundName = nil;
            
            NSRange emailRange = [jsonStr rangeOfString:@"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}" options:NSRegularExpressionSearch];
            if (emailRange.location != NSNotFound) {
                foundEmail = [jsonStr substringWithRange:emailRange];
            }
            
            if ([json objectForKey:@"actions"]) {
                NSArray *actions = [json objectForKey:@"actions"];
                if (actions.count > 0) {
                    NSDictionary *act = [actions firstObject];
                    NSDictionary *header = [act valueForKeyPath:@"openPopupAction.popup.multiPageMenuPopupRenderer.header.activeAccountHeaderRenderer"];
                    if (header) {
                        NSDictionary *accountName = [header objectForKey:@"accountName"];
                        if ([accountName objectForKey:@"simpleText"]) {
                            foundName = [accountName objectForKey:@"simpleText"];
                        }
                        NSDictionary *emailObj = [header objectForKey:@"email"];
                        if ([emailObj objectForKey:@"simpleText"]) {
                            foundEmail = [emailObj objectForKey:@"simpleText"];
                        }
                    }
                }
            }
            
            if (foundEmail || foundName) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self saveUserInfo:foundName email:foundEmail channelId:nil avatarUrl:nil];
                });
            }
        }
    });
}

- (void)logout {
    self.loggedIn = NO;
    self.userName = nil;
    self.userEmail = nil;
    self.channelId = nil;
    self.avatarUrl = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthSAPISID];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthUsernameKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthUserEmailKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthChannelIdKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthAvatarUrlKey];
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

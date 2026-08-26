#import <Foundation/Foundation.h>

extern NSString *const AuthStateChangedNotification;

@interface AuthManager : NSObject

@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;
@property (nonatomic, readonly, copy) NSString *userName;
@property (nonatomic, readonly, copy) NSString *channelId;

@property (nonatomic, readonly, copy) NSString *deviceUUID;

+ (instancetype)sharedManager;

- (void)checkLoginState;
- (void)saveSAPISID:(NSString *)sapisid;
- (void)saveUserInfo:(NSString *)name channelId:(NSString *)channelId;
- (void)logout;
- (NSString *)sapisidHashHeader;
- (NSString *)sapisidCookie;

@end

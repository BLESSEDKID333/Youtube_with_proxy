#import <Foundation/Foundation.h>

extern NSString *const AuthStateChangedNotification;

@interface AuthManager : NSObject

@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;
@property (nonatomic, readonly, copy) NSString *userName;
@property (nonatomic, readonly, copy) NSString *userEmail;
@property (nonatomic, readonly, copy) NSString *channelId;
@property (nonatomic, readonly, copy) NSString *avatarUrl;

@property (nonatomic, readonly, copy) NSString *deviceUUID;

+ (instancetype)sharedManager;

- (void)checkLoginState;
- (void)saveSAPISID:(NSString *)sapisid;
- (void)saveUserInfo:(NSString *)name channelId:(NSString *)channelId;
- (void)saveUserInfo:(NSString *)name email:(NSString *)email channelId:(NSString *)channelId avatarUrl:(NSString *)avatarUrl;
- (void)fetchAccountProfile;
- (void)logout;
- (NSString *)sapisidHashHeader;
- (NSString *)sapisidCookie;

@end

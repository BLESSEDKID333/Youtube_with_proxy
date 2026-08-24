//
//  AppDelegate.m
//  YouTube
//
//  App Delegate for YouTube iOS 6 Client
//

#import "AppDelegate.h"
#import "MainTabBarController.h"
#import "Constants.h"
#import "DebugLog.h"
#import "YouTubeProxyURLProtocol.h"

// Global crash handler
static void UncaughtExceptionHandler(NSException *exception) {
    WriteCrashReport(exception);
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Install crash handler FIRST
    NSSetUncaughtExceptionHandler(&UncaughtExceptionHandler);

    // Initialize debug logging
    DebugLogInit();
    DLog(@"App starting...");

    // Register URL protocol for YouTube proxy
    [YouTubeProxyURLProtocol registerProtocol];
    DLog(@"YouTube proxy URL protocol registered");

    // Create window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = COLOR_DARK_BG;
    DLog(@"Window created, bounds: %@", NSStringFromCGRect(self.window.bounds));

    // Create tab bar controller as root
    MainTabBarController *tabBarController = [[MainTabBarController alloc] init];
    DLog(@"MainTabBarController created");

    // Set root
    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    DLog(@"Window made key and visible");

    // Style status bar
    [[UIApplication sharedApplication] setStatusBarStyle:1 animated:NO];

    // Register for remote notifications (optional)
    if ([application respondsToSelector:@selector(registerForRemoteNotificationTypes:)]) {
        [application registerForRemoteNotificationTypes:
            (UIRemoteNotificationTypeBadge |
             UIRemoteNotificationTypeSound |
             UIRemoteNotificationTypeAlert)];
    }

    DLog(@"App launch complete");
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    DLog(@"App entering foreground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DLog(@"App terminating");
}

#pragma mark - Remote Notifications

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    DLog(@"Registered for remote notifications");
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DLog(@"Failed to register for remote notifications: %@", [error localizedDescription]);
}

@end

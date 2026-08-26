#import "UIStyleManager.h"
#import "Constants.h"

@interface NSObject (YTBarTintCompat)
- (void)setBarTintColor:(UIColor *)color;
@end

@implementation UIStyleManager

+ (UIColor *)barBackgroundColor {
    if (IOS7StyleEnabled()) {
        return [UIColor colorWithRed:230.0/255.0 green:33.0/255.0 blue:23.0/255.0 alpha:1.0];
    }
    return [UIColor whiteColor];
}

+ (UIColor *)barTintColor {
    if (IOS7StyleEnabled()) {
        return [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    }
    return [UIColor whiteColor];
}

+ (void)applyGlobalAppearance {
    // If iOS 7 style is disabled (default), do NOT override navigation bar or tab bar tinting.
    // This allows iOS 6 SDK to render its 100% native built-in blue/silver glossy gradient bars,
    // identical to standard iOS 6 system apps like Settings, Clock, and Phone.
    if (!IOS7StyleEnabled()) {
        return;
    }

    UINavigationBar *navBarAppearance = [UINavigationBar appearance];
    UITabBar *tabBarAppearance = [UITabBar appearance];

    // iOS 7 flat style: flat YouTube red navigation bar and light tab bar
    UIColor *flatRed = [UIColor colorWithRed:230.0/255.0 green:33.0/255.0 blue:23.0/255.0 alpha:1.0];
    if ([navBarAppearance respondsToSelector:@selector(setBarTintColor:)]) {
        [navBarAppearance setBarTintColor:flatRed];
        [navBarAppearance setTranslucent:NO];
        [tabBarAppearance setBarTintColor:[UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:248.0/255.0 alpha:1.0]];
    } else {
        [navBarAppearance setTintColor:flatRed];
        [tabBarAppearance setTintColor:[UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:248.0/255.0 alpha:1.0]];
    }
    NSDictionary *titleAttrs = @{
        UITextAttributeTextColor: [UIColor whiteColor],
        UITextAttributeTextShadowColor: [UIColor clearColor]
    };
    [navBarAppearance setTitleTextAttributes:titleAttrs];
}

@end

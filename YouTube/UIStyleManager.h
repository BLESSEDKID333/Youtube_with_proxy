//
//  UIStyleManager.h
//  YouTube
//
//  Switches the app between the classic iOS 6 look and a flatter
//  "iOS 7 Style" (toggled in Settings). Uses UIAppearance so it applies
//  app-wide; a full effect requires relaunch, which Settings prompts for.
//

#import <UIKit/UIKit.h>

@interface UIStyleManager : NSObject

// Applies the appearance for the current IOS7StyleEnabled() setting.
+ (void)applyGlobalAppearance;

// Convenience color used across the UI for the current style.
+ (UIColor *)barBackgroundColor;
+ (UIColor *)barTintColor;

@end

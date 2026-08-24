//
//  MainTabBarController.m
//  YouTube
//
//  Tab bar controller - root of the app
//

#import "MainTabBarController.h"
#import "TrendingViewController.h"
#import "CategoriesViewController.h"
#import "SearchViewController.h"
#import "SubscriptionsViewController.h"
#import "SettingsViewController.h"
#import "Constants.h"

@implementation MainTabBarController

- (id)init {
    self = [super init];
    if (self) {
        [self setupTabBar];
        [self setupViewControllers];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = COLOR_WHITE;
}

- (void)setupTabBar {
    // YouTube-style dark tab bar
    

    // barTintColor is iOS 7+ — use KVC for iOS 6 compat
    if ([self.tabBar respondsToSelector:@selector(setBarTintColor:)]) {
        
    }
    
}

- (void)setupViewControllers {
    // Tab 1: Trending — Featured tab icon
    TrendingViewController *trendingVC = [[TrendingViewController alloc] init];
    UINavigationController *trendingNav = [[UINavigationController alloc] initWithRootViewController:trendingVC];
    trendingNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
    trendingNav.tabBarItem.title = @"Trending";

    // Tab 2: Categories — Most Viewed icon
    CategoriesViewController *categoriesVC = [[CategoriesViewController alloc] init];
    UINavigationController *categoriesNav = [[UINavigationController alloc] initWithRootViewController:categoriesVC];
    categoriesNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMostViewed tag:1];
    categoriesNav.tabBarItem.title = @"Categories";

    // Tab 3: Search — built-in search icon
    SearchViewController *searchVC = [[SearchViewController alloc] init];
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:2];

    // Tab 4: Subscriptions — built-in bookmarks icon
    SubscriptionsViewController *subsVC = [[SubscriptionsViewController alloc] init];
    UINavigationController *subsNav = [[UINavigationController alloc] initWithRootViewController:subsVC];
    subsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:3];
    subsNav.tabBarItem.title = @"Subs";

    // Tab 5: Settings — built-in more icon (looks like gear area in iOS 6)
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:4];

    self.viewControllers = @[trendingNav, categoriesNav, searchNav, subsNav, settingsNav];
    self.selectedIndex = 0;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return 1; // UIStatusBarStyleBlackTranslucent (same value as UIStatusBarStyleLightContent)
}

@end

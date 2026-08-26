//
//  MainTabBarController.m
//  YouTube
//
//  Tab bar controller - root of the app
//

#import "MainTabBarController.h"
#import "TrendingViewController.h"
#import "ShortsViewController.h"
#import "CategoriesViewController.h"
#import "SearchViewController.h"
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
    if ([self.tabBar respondsToSelector:@selector(setBarTintColor:)]) {
    }
}

- (void)setupViewControllers {
    // Tab 1: Trending
    TrendingViewController *trendingVC = [[TrendingViewController alloc] init];
    UINavigationController *trendingNav = [[UINavigationController alloc] initWithRootViewController:trendingVC];
    trendingNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
    trendingNav.tabBarItem.title = @"Trending";

    // Tab 2: Shorts
    ShortsViewController *shortsVC = [[ShortsViewController alloc] init];
    UINavigationController *shortsNav = [[UINavigationController alloc] initWithRootViewController:shortsVC];
    shortsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemTopRated tag:1];
    shortsNav.tabBarItem.title = @"Shorts";

    // Tab 3: Categories
    CategoriesViewController *categoriesVC = [[CategoriesViewController alloc] init];
    UINavigationController *categoriesNav = [[UINavigationController alloc] initWithRootViewController:categoriesVC];
    categoriesNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMostViewed tag:2];
    categoriesNav.tabBarItem.title = @"Categories";

    // Tab 4: Search
    SearchViewController *searchVC = [[SearchViewController alloc] init];
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:3];

    // Tab 5: Settings (with Bookmarks/Subscriptions inside)
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:4];

    self.viewControllers = @[trendingNav, shortsNav, categoriesNav, searchNav, settingsNav];
    self.selectedIndex = 0;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return 1;
}

@end

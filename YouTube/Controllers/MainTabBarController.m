//
//  MainTabBarController.m
//  YouTube
//
//  Tab bar controller - root of the app
//

#import "MainTabBarController.h"
#import "TrendingViewController.h"
#import "ShortsViewController.h"
#import "SubscriptionsViewController.h"
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
}

- (void)setupViewControllers {
    // Tab 1: Главная (Home / Recommendations)
    TrendingViewController *trendingVC = [[TrendingViewController alloc] init];
    UINavigationController *trendingNav = [[UINavigationController alloc] initWithRootViewController:trendingVC];
    trendingNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
    trendingNav.tabBarItem.title = @"Главная";

    // Tab 2: Shorts
    ShortsViewController *shortsVC = [[ShortsViewController alloc] init];
    UINavigationController *shortsNav = [[UINavigationController alloc] initWithRootViewController:shortsVC];
    shortsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemTopRated tag:1];
    shortsNav.tabBarItem.title = @"Shorts";

    // Tab 3: Подписки (Subscriptions)
    SubscriptionsViewController *subscriptionsVC = [[SubscriptionsViewController alloc] init];
    UINavigationController *subscriptionsNav = [[UINavigationController alloc] initWithRootViewController:subscriptionsVC];
    subscriptionsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:2];
    subscriptionsNav.tabBarItem.title = @"Подписки";

    // Tab 4: Поиск (Search)
    SearchViewController *searchVC = [[SearchViewController alloc] init];
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:3];
    searchNav.tabBarItem.title = @"Поиск";

    // Tab 5: Настройки (Settings)
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:4];
    settingsNav.tabBarItem.title = @"Настройки";

    self.viewControllers = @[trendingNav, shortsNav, subscriptionsNav, searchNav, settingsNav];
    self.selectedIndex = 0;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return 1;
}

@end

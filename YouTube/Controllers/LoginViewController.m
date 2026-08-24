#import "LoginViewController.h"
#import "WebLoginViewController.h"
#import "Constants.h"
#import "AuthManager.h"
#import "DebugLog.h"

@interface LoginViewController ()
@end

@implementation LoginViewController
- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { self.title = @"Sign In"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLoginComplete:) name:AuthStateChangedNotification object:nil];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelTapped)];
    
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 80)];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btn.frame = CGRectMake(20, 15, self.view.frame.size.width - 40, 44);
    [btn setTitle:@"Sign In with YouTube" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(loginTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:btn];
    self.tableView.tableFooterView = footer;
}
- (void)cancelTapped { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)loginTapped {
    WebLoginViewController *webVC = [[WebLoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVC];
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)handleLoginComplete:(NSNotification *)n {
    if ([AuthManager sharedManager].loggedIn) { [self dismissViewControllerAnimated:YES completion:nil]; }
}
@end

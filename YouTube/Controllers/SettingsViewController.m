#import "SettingsViewController.h"
#import "BypassSettingsViewController.h"
#import "LoginViewController.h"
#import "AuthManager.h"
#import "Constants.h"

@implementation SettingsViewController
- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { self.title = @"Settings"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged) name:AuthStateChangedNotification object:nil];
}
- (void)authChanged { [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 1; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"]; }
    if (ip.section == 0) {
        if ([AuthManager sharedManager].loggedIn) {
            cell.textLabel.text = @"Sign Out";
            cell.textLabel.textColor = [UIColor redColor];
        } else {
            cell.textLabel.text = @"Sign In";
            cell.textLabel.textColor = [UIColor blackColor];
        }
    } else {
        cell.textLabel.text = @"VPS Bypass Settings";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) {
        if ([AuthManager sharedManager].loggedIn) {
            [[AuthManager sharedManager] logout];
        } else {
            LoginViewController *lvc = [[LoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:lvc];
            [self presentViewController:nav animated:YES completion:nil];
        }
    } else {
        BypassSettingsViewController *bvc = [[BypassSettingsViewController alloc] init];
        [self.navigationController pushViewController:bvc animated:YES];
    }
}
@end

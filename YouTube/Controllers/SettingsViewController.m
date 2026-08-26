#import "SettingsViewController.h"
#import "BypassSettingsViewController.h"
#import "SubscriptionsViewController.h"
#import "LoginViewController.h"
#import "AuthManager.h"
#import "Constants.h"
#import "UIStyleManager.h"

@interface SettingsViewController ()
@property (nonatomic, strong) UISwitch *ios7Switch;
@end

@implementation SettingsViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Settings";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authChanged)
                                                 name:AuthStateChangedNotification
                                               object:nil];
}

- (void)authChanged {
    [self.tableView reloadData];
}

// Sections: 0 = account, 1 = library, 2 = appearance, 3 = network, 4 = developers
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 4) return 3;
    return 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 1) return @"Library";
    if (s == 2) return @"Appearance";
    if (s == 3) return @"Network";
    if (s == 4) return @"Developers / Разработчики";
    return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 2) return @"Switches to a flatter iOS 7-style look. Relaunch the app to fully apply.";
    if (s == 4) return @"YouTube Client for iOS 6";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];

    if (ip.section == 0) {
        if ([AuthManager sharedManager].isLoggedIn) {
            NSString *email = [AuthManager sharedManager].userEmail;
            NSString *name = [AuthManager sharedManager].userName;
            if (email && email.length > 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"Выйти (%@)", email];
            } else if (name && name.length > 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"Выйти (%@)", name];
            } else {
                cell.textLabel.text = @"Выйти из аккаунта (Sign Out)";
            }
            cell.textLabel.textColor = [UIColor redColor];
        } else {
            cell.textLabel.text = @"Войти в аккаунт (Sign In)";
            cell.textLabel.textColor = COLOR_YOUTUBE_RED;
        }
    } else if (ip.section == 1) {
        cell.textLabel.text = @"Bookmarks & Subscriptions";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.section == 2) {
        cell.textLabel.text = @"iOS 7 Style";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (!self.ios7Switch) {
            self.ios7Switch = [[UISwitch alloc] init];
            self.ios7Switch.on = IOS7StyleEnabled();
            [self.ios7Switch addTarget:self action:@selector(ios7SwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = self.ios7Switch;
    } else if (ip.section == 3) {
        cell.textLabel.text = @"Proxy Settings";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.section == 4) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (ip.row == 0) {
            cell.textLabel.text = @"Аназерка";
            cell.detailTextLabel.text = @"@anazerka";
        } else if (ip.row == 1) {
            cell.textLabel.text = @"Виктор";
            cell.detailTextLabel.text = @"@nothack4d";
        } else if (ip.row == 2) {
            cell.textLabel.text = @"Непобедимый";
            cell.detailTextLabel.text = @"@BLESSEDKID87";
        }
    }

    return cell;
}

- (void)ios7SwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:IOS7_STYLE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [UIStyleManager applyGlobalAppearance];
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"iOS 7 Style"
                                                message:(sw.on ? @"Enabled. Relaunch to fully apply." : @"Disabled. Relaunch to fully apply.")
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil];
    [a show];
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
    } else if (ip.section == 1) {
        SubscriptionsViewController *svc = [[SubscriptionsViewController alloc] init];
        [self.navigationController pushViewController:svc animated:YES];
    } else if (ip.section == 3) {
        BypassSettingsViewController *bvc = [[BypassSettingsViewController alloc] init];
        [self.navigationController pushViewController:bvc animated:YES];
    } else if (ip.section == 4) {
        NSString *handle = @"";
        if (ip.row == 0) handle = @"anazerka";
        else if (ip.row == 1) handle = @"nothack4d";
        else if (ip.row == 2) handle = @"BLESSEDKID87";

        if (handle.length > 0) {
            NSString *tgUrl = [NSString stringWithFormat:@"https://t.me/%@", handle];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:tgUrl]];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

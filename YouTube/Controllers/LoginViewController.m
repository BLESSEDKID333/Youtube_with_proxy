#import "LoginViewController.h"
#import "WebLoginViewController.h"
#import "NativeQRLoginViewController.h"
#import "Constants.h"
#import "AuthManager.h"
#import "DebugLog.h"

@interface LoginViewController () <UIAlertViewDelegate>
@end

@implementation LoginViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Sign In";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLoginComplete:)
                                                 name:AuthStateChangedNotification
                                               object:nil];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered
                                        target:self action:@selector(cancelTapped)];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Choose Sign-In Method" : @"Manual Authorization";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Native QR & Cookie input runs 100% locally on device without VPS.";
    } else {
        return @"Enter your SAPISID cookie directly if web sign-in is unsupported by Google.";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"LoginCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Вход через Google (Логин и пароль)";
            cell.detailTextLabel.text = @"Вход в браузере Google (Авто-закрытие)";
            cell.textLabel.textColor = COLOR_YOUTUBE_RED;
        } else {
            cell.textLabel.text = @"Вход по QR-коду / Куки";
            cell.detailTextLabel.text = @"Сканирование QR или ввод SAPISID";
            cell.textLabel.textColor = [UIColor blackColor];
        }
    } else {
        cell.textLabel.text = @"Ввести куки SAPISID вручную";
        cell.detailTextLabel.text = @"Быстрое окно ввода для продвинутых";
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:1.0];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            WebLoginViewController *webVC = [[WebLoginViewController alloc] initWithMode:@"direct"];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVC];
            [self presentViewController:nav animated:YES completion:nil];
        } else {
            NativeQRLoginViewController *nvc = [[NativeQRLoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:nvc];
            [self presentViewController:nav animated:YES completion:nil];
        }
    } else {
        [self showManualCookiePrompt];
    }
}

- (void)showManualCookiePrompt {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Manual Cookie Input"
                                                    message:@"Paste your Google SAPISID cookie value below:"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 888;
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 888 && buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *val = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (val.length > 0) {
            if ([val rangeOfString:@"SAPISID="].location != NSNotFound) {
                NSArray *parts = [val componentsSeparatedByString:@";"];
                for (NSString *p in parts) {
                    NSString *tp = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    if ([tp hasPrefix:@"SAPISID="]) {
                        val = [tp substringFromIndex:8];
                        break;
                    }
                }
            }
            [[AuthManager sharedManager] saveSAPISID:val];
            [[AuthManager sharedManager] checkLoginState];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)handleLoginComplete:(NSNotification *)n {
    if ([AuthManager sharedManager].loggedIn) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

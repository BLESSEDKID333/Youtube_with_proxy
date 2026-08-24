#import "BypassSettingsViewController.h"
#import "Constants.h"

@interface BypassSettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UISwitch *bypassSwitch;
@property (nonatomic, strong) UITextField *proxyField;
@end

@implementation BypassSettingsViewController
- (id)init { self = [super initWithStyle:UITableViewStyleGrouped]; if (self) { self.title = @"VPS Bypass"; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 2; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (ip.row == 0) {
        cell.textLabel.text = @"Enable Bypass";
        self.bypassSwitch = [[UISwitch alloc] init];
        self.bypassSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:VPS_BYPASS_KEY];
        [self.bypassSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.bypassSwitch;
    } else {
        cell.textLabel.text = @"Proxy URL";
        self.proxyField = [[UITextField alloc] initWithFrame:CGRectMake(100, 10, 200, 24)];
        self.proxyField.text = [[NSUserDefaults standardUserDefaults] stringForKey:VPS_PROXY_KEY] ?: VPS_PROXY_DEFAULT;
        self.proxyField.delegate = self;
        self.proxyField.returnKeyType = UIReturnKeyDone;
        [cell.contentView addSubview:self.proxyField];
    }
    return cell;
}
- (void)switchChanged {
    [[NSUserDefaults standardUserDefaults] setBool:self.bypassSwitch.on forKey:VPS_BYPASS_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    [[NSUserDefaults standardUserDefaults] setObject:tf.text forKey:VPS_PROXY_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}
@end

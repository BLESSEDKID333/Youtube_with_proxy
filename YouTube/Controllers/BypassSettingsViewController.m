#import "BypassSettingsViewController.h"
#import "Constants.h"

@interface BypassSettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UISwitch *bypassSwitch;
@property (nonatomic, strong) NSMutableArray *hostsList;
@property (nonatomic, assign) NSInteger activeIndex;
@property (nonatomic, strong) UITextField *customHostField;
@end

@implementation BypassSettingsViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Proxy Settings";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadHostsList];
}

- (void)loadHostsList {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:VPS_HOSTS_LIST_KEY];
    if (saved && [saved count] > 0) {
        self.hostsList = [NSMutableArray arrayWithArray:saved];
    } else {
        self.hostsList = [NSMutableArray arrayWithObjects:VPS_PROXY_DEFAULT, nil];
        [[NSUserDefaults standardUserDefaults] setObject:self.hostsList forKey:VPS_HOSTS_LIST_KEY];
    }
    self.activeIndex = [[NSUserDefaults standardUserDefaults] integerForKey:VPS_ACTIVE_INDEX_KEY];
    if (self.activeIndex < 0 || self.activeIndex >= [self.hostsList count]) {
        self.activeIndex = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:VPS_ACTIVE_INDEX_KEY];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveHostsState {
    [[NSUserDefaults standardUserDefaults] setObject:self.hostsList forKey:VPS_HOSTS_LIST_KEY];
    [[NSUserDefaults standardUserDefaults] setInteger:self.activeIndex forKey:VPS_ACTIVE_INDEX_KEY];
    if (self.activeIndex < [self.hostsList count]) {
        [[NSUserDefaults standardUserDefaults] setObject:[self.hostsList objectAtIndex:self.activeIndex] forKey:VPS_PROXY_KEY];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 1; // Switch
    if (s == 1) return [self.hostsList count]; // Hosts list
    if (s == 2) return 2; // Add host (TextField + Add button)
    return 1; // Reset
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"Proxy Bypass";
    if (s == 1) return @"Select Active Proxy Host";
    if (s == 2) return @"Add Custom Proxy Host";
    return @"Reset";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 1) {
        return @"Tap a host to activate it for all video playback and API requests. Swipe left to delete custom hosts.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (ip.section == 0) {
        cell.textLabel.text = @"Enable Proxy Bypass";
        if (!self.bypassSwitch) {
            self.bypassSwitch = [[UISwitch alloc] init];
            self.bypassSwitch.on = VPSBypassEnabled();
            [self.bypassSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = self.bypassSwitch;
    } else if (ip.section == 1) {
        NSString *host = [self.hostsList objectAtIndex:ip.row];
        cell.textLabel.text = host;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (ip.row == self.activeIndex) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:1.0];
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor blackColor];
        }
    } else if (ip.section == 2) {
        if (ip.row == 0) {
            cell.textLabel.text = @"Host";
            CGFloat w = self.view.bounds.size.width;
            self.customHostField = [[UITextField alloc] initWithFrame:CGRectMake(80, 10, w - 100, 24)];
            self.customHostField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            self.customHostField.placeholder = @"http://45.12.34.56";
            self.customHostField.keyboardType = UIKeyboardTypeURL;
            self.customHostField.autocorrectionType = UITextAutocorrectionTypeNo;
            self.customHostField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            self.customHostField.delegate = self;
            self.customHostField.returnKeyType = UIReturnKeyDone;
            [cell.contentView addSubview:self.customHostField];
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = @"Add Proxy Host";
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:1.0];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = @"Reset Host List to Default";
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == 1) {
        // Select active host
        self.activeIndex = ip.row;
        [self saveHostsState];
        [self.tableView reloadData];

        NSString *selectedHost = [self.hostsList objectAtIndex:ip.row];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Proxy Activated"
                                                        message:[NSString stringWithFormat:@"Active proxy changed to:\n%@", selectedHost]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    } else if (ip.section == 2 && ip.row == 1) {
        // Add Proxy Host button tapped
        [self addCustomHost];
    } else if (ip.section == 3) {
        // Reset list
        [self resetHostsList];
    }
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return (ip.section == 1 && [self.hostsList count] > 1);
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)ip {
    if (editingStyle == UITableViewCellEditingStyleDelete && ip.section == 1) {
        [self.hostsList removeObjectAtIndex:ip.row];
        if (self.activeIndex >= [self.hostsList count]) {
            self.activeIndex = [self.hostsList count] - 1;
        }
        [self saveHostsState];
        [self.tableView reloadData];
    }
}

#pragma mark - Actions

- (void)switchChanged {
    [[NSUserDefaults standardUserDefaults] setBool:self.bypassSwitch.on forKey:VPS_BYPASS_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addCustomHost {
    [self.customHostField resignFirstResponder];
    NSString *text = [self.customHostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0) {
        if (![text hasPrefix:@"http://"] && ![text hasPrefix:@"https://"]) {
            text = [NSString stringWithFormat:@"http://%@", text];
        }
        if (![self.hostsList containsObject:text]) {
            [self.hostsList addObject:text];
        }
        self.activeIndex = [self.hostsList indexOfObject:text];
        [self saveHostsState];
        self.customHostField.text = @"";
        [self.tableView reloadData];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Host Added"
                                                        message:[NSString stringWithFormat:@"Added and activated proxy host:\n%@", text]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)resetHostsList {
    [self.customHostField resignFirstResponder];
    self.hostsList = [NSMutableArray arrayWithObjects:VPS_PROXY_DEFAULT, nil];
    self.activeIndex = 0;
    [self saveHostsState];
    [self.tableView reloadData];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Proxy Reset"
                                                    message:[NSString stringWithFormat:@"Proxy list reset to default:\n%@", VPS_PROXY_DEFAULT]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [self addCustomHost];
    return YES;
}

@end

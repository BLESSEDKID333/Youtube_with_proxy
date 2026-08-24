#import "CategoriesViewController.h"
#import "CategoryVideosViewController.h"
#import "Constants.h"

@interface CategoriesViewController ()
@property (nonatomic, strong) NSArray *categories;
@end

@implementation CategoriesViewController
- (id)init { self = [super initWithStyle:UITableViewStylePlain]; if (self) { self.title = @"Categories"; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.categories = @[
        @{@"id": CATEGORY_ID_MUSIC, @"name": @"Music"},
        @{@"id": CATEGORY_ID_GAMING, @"name": @"Gaming"},
        @{@"id": CATEGORY_ID_MOVIES, @"name": @"Movies"},
        @{@"id": CATEGORY_ID_NEWS, @"name": @"News"},
        @{@"id": CATEGORY_ID_SPORTS, @"name": @"Sports"}
    ];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.categories.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    cell.textLabel.text = self.categories[ip.row][@"name"];
    return cell;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    CategoryVideosViewController *cvc = [[CategoryVideosViewController alloc] initWithCategory:self.categories[ip.row][@"id"] title:self.categories[ip.row][@"name"]];
    [self.navigationController pushViewController:cvc animated:YES];
}
@end

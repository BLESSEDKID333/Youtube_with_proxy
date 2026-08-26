#import "SubscriptionsViewController.h"
#import "ChannelViewController.h"
#import "YTVideo.h"
#import "YouTubeAPIManager.h"

@interface SubscriptionsViewController () <YouTubeAPIManagerDelegate>
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *channels;
@end

@implementation SubscriptionsViewController
- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Subscriptions";
        _channels = @[];
        _apiManager = [[YouTubeAPIManager alloc] init];
        _apiManager.delegate = self;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self.apiManager fetchSubscriptions];
}
- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)c forCategory:(NSString *)cat {
    self.channels = c;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.channels.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    YTVideo *v = self.channels[ip.row];
    cell.textLabel.text = v.channelTitle ?: v.title;
    return cell;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    YTVideo *v = self.channels[ip.row];
    ChannelViewController *cvc = [[ChannelViewController alloc] initWithChannelId:v.channelId title:v.channelTitle ?: v.title];
    [self.navigationController pushViewController:cvc animated:YES];
}
@end

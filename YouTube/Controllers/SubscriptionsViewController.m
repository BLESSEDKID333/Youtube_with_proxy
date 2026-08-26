#import "SubscriptionsViewController.h"
#import "ChannelViewController.h"
#import "VideoPlayerViewController.h"
#import "YTVideo.h"
#import "YouTubeAPIManager.h"
#import "ImageCacheManager.h"
#import "AuthManager.h"
#import "Constants.h"

@interface SubscriptionsViewController () <YouTubeAPIManagerDelegate>
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *channels;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
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
    self.view.backgroundColor = [UIColor whiteColor];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadData) forControlEvents:UIControlEventValueChanged];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 160);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    [self loadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.channels.count == 0 && !self.apiManager.isLoading) {
        [self loadData];
    }
}

- (void)loadData {
    if (!self.apiManager.isLoading) {
        [self.spinner startAnimating];
        [self.apiManager fetchSubscriptions];
    }
}

- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)c forCategory:(NSString *)cat {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        self.channels = c ?: @[];
        [self.tableView reloadData];
    });
}

- (void)apiManager:(YouTubeAPIManager *)m didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.channels.count;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cellId = @"SubCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.layer.cornerRadius = 22.0;
        cell.imageView.clipsToBounds = YES;
    }
    YTVideo *v = self.channels[ip.row];
    cell.textLabel.text = v.channelTitle ?: v.title;
    cell.detailTextLabel.text = v.subscriberCount ?: (v.isChannel ? @"Channel" : @"Video");

    cell.imageView.image = [UIImage imageNamed:@"Default.png"];
    if (v.thumbnailURL.length > 0) {
        [[ImageCacheManager sharedCache] loadImageFromURL:v.thumbnailURL completion:^(UIImage *image) {
            if (image && [tv indexPathForCell:cell].row == ip.row) {
                cell.imageView.image = image;
                [cell setNeedsLayout];
            }
        }];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    YTVideo *v = self.channels[ip.row];
    if (v.isChannel && v.channelId) {
        ChannelViewController *cvc = [[ChannelViewController alloc] initWithChannelId:v.channelId title:v.channelTitle ?: v.title];
        [self.navigationController pushViewController:cvc animated:YES];
    } else if (v.videoId) {
        VideoPlayerViewController *vc = [[VideoPlayerViewController alloc] initWithVideo:v];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end

#import "ChannelViewController.h"
#import "VideoCell.h"
#import "VideoPlayerViewController.h"

@interface ChannelViewController () <YouTubeAPIManagerDelegate>
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ChannelViewController

- (id)initWithChannelId:(NSString *)channelId title:(NSString *)title {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = title.length > 0 ? title : @"Channel";
        _channelId = channelId;
        _videos = @[];
        _apiManager = [[YouTubeAPIManager alloc] init];
        _apiManager.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [VideoCell cellHeight];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 150);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    NSString *query = self.title;
    if (!query || query.length == 0) query = self.channelId;
    if (query && query.length > 0) {
        [self.apiManager searchFromWeb:query];
    } else {
        [self.spinner stopAnimating];
    }
}

- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)v forCategory:(NSString *)c {
    [self.spinner stopAnimating];
    if (v && v.count > 0) {
        self.videos = v;
        [self.tableView reloadData];
    }
}

- (void)apiManager:(YouTubeAPIManager *)m didReceiveSearchResults:(NSArray *)v nextPageToken:(NSString *)t {
    [self.spinner stopAnimating];
    if (v && v.count > 0) {
        self.videos = v;
        [self.tableView reloadData];
    }
}

- (void)apiManager:(YouTubeAPIManager *)m didFailWithError:(NSError *)error {
    [self.spinner stopAnimating];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.videos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    VideoCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) { cell = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"]; }
    [cell configureWithVideo:self.videos[ip.row]];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    VideoPlayerViewController *vp = [[VideoPlayerViewController alloc] initWithVideo:self.videos[ip.row]];
    [self.navigationController pushViewController:vp animated:YES];
}

@end

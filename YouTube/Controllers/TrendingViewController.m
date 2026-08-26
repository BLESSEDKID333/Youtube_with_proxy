#import "TrendingViewController.h"
#import "VideoCell.h"
#import "VideoPlayerViewController.h"
#import "Constants.h"
#import "DebugLog.h"

@interface TrendingViewController () <YouTubeAPIManagerDelegate>
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@end

@implementation TrendingViewController

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Trending";
        _videos = [NSArray array];
        _apiManager = [[YouTubeAPIManager alloc] init];
        _apiManager.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.tableView.rowHeight = [VideoCell cellHeight];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadVideos) forControlEvents:UIControlEventValueChanged];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2.0, 200);
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.loadingIndicator];

    [self loadVideos];
}

- (void)loadVideos {
    if (self.videos.count == 0) {
        [self.loadingIndicator startAnimating];
    }
    [self.apiManager fetchTrendingFromWeb];
}

#pragma mark - YouTubeAPIManagerDelegate

- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)v forCategory:(NSString *)c {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self.refreshControl endRefreshing];
        if (v && v.count > 0) {
            self.videos = v;
            [self.tableView reloadData];
        } else {
            DLog(@"Trending received empty array, retrying search...");
            [self.apiManager searchFromWeb:@"trending videos"];
        }
    });
}

- (void)apiManager:(YouTubeAPIManager *)m didReceiveSearchResults:(NSArray *)v nextPageToken:(NSString *)t {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self.refreshControl endRefreshing];
        self.videos = v;
        [self.tableView reloadData];
    });
}

- (void)apiManager:(YouTubeAPIManager *)m didFailWithError:(NSError *)e {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self.refreshControl endRefreshing];
    });
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.videos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    VideoCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    if (ip.row < self.videos.count) {
        [cell configureWithVideo:[self.videos objectAtIndex:ip.row]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.row < self.videos.count) {
        VideoPlayerViewController *vp = [[VideoPlayerViewController alloc] initWithVideo:[self.videos objectAtIndex:ip.row]];
        [self.navigationController pushViewController:vp animated:YES];
    }
}

@end

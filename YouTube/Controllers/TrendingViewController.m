#import "TrendingViewController.h"
#import "VideoCell.h"
#import "VideoPlayerViewController.h"

@interface TrendingViewController ()
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@end

@implementation TrendingViewController
- (id)init { self = [super initWithStyle:UITableViewStylePlain]; if (self) { self.title = @"Trending"; _videos = @[]; _apiManager = [[YouTubeAPIManager alloc] init]; _apiManager.delegate = self; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [VideoCell cellHeight];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadVideos) forControlEvents:UIControlEventValueChanged];
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2);
    [self.view addSubview:self.loadingIndicator];
    [self loadVideos];
}
- (void)loadVideos {
    if (self.videos.count == 0) [self.loadingIndicator startAnimating];
    [self.apiManager fetchTrendingFromWeb];
}
- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)v forCategory:(NSString *)c {
    [self.loadingIndicator stopAnimating];
    [self.refreshControl endRefreshing];
    self.videos = v;
    [self.tableView reloadData];
}
- (void)apiManager:(YouTubeAPIManager *)m didFailWithError:(NSError *)e {
    [self.loadingIndicator stopAnimating];
    [self.refreshControl endRefreshing];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.videos.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    VideoCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) { cell = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"]; }
    [cell configureWithVideo:self.videos[ip.row]];
    return cell;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    VideoPlayerViewController *vp = [[VideoPlayerViewController alloc] initWithVideo:self.videos[ip.row]];
    [self.navigationController pushViewController:vp animated:YES];
}
@end

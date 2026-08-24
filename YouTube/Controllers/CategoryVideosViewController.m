//
//  CategoryVideosViewController.m
//  YouTube
//
//  Videos within a specific category — InnerTube Web API
//

#import "CategoryVideosViewController.h"
#import "VideoCell.h"
#import "YTVideo.h"
#import "VideoPlayerViewController.h"
#import "Constants.h"
#import "VideoURLCache.h"

@interface CategoryVideosViewController ()
@property (nonatomic, copy) NSString *categoryId;
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy) NSString *nextPageToken;
@end

@implementation CategoryVideosViewController

- (void)dealloc {
    _apiManager.delegate = nil;
    [_apiManager cancelAllRequests];
}

- (id)initWithCategory:(NSString *)categoryId title:(NSString *)title {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _categoryId = [categoryId copy];
        self.title = title;
        _videos = [NSArray array];
        _apiManager = [[YouTubeAPIManager alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = COLOR_WHITE;
    self.navigationItem.title = self.title;

    self.tableView.rowHeight = [VideoCell cellHeight];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = COLOR_YOUTUBE_RED;
    [self.refreshControl addTarget:self action:@selector(refreshContent) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;

    [self loadVideos];
}

- (void)loadVideos {
    // Map API v3 category IDs to names for InnerTube search
    NSString *categoryName = [self categoryNameFromId:self.categoryId];
    self.apiManager.delegate = self;
    [self.apiManager fetchCategoryFromWeb:categoryName];
}

- (NSString *)categoryNameFromId:(NSString *)categoryId {
    // Map common YouTube category IDs to searchable names
    NSDictionary *map = @{
        @"1": @"Film & Animation",
        @"2": @"Autos & Vehicles",
        @"10": @"Music",
        @"15": @"Pets & Animals",
        @"17": @"Sports",
        @"18": @"Short Movies",
        @"19": @"Travel & Events",
        @"20": @"Gaming",
        @"22": @"People & Blogs",
        @"23": @"Comedy",
        @"24": @"Entertainment",
        @"25": @"News & Politics",
        @"26": @"Howto & Style",
        @"27": @"Education",
        @"28": @"Science & Technology"
    };
    NSString *name = [map objectForKey:categoryId];
    return name ?: @"Popular";
}

- (void)refreshContent {
    [self.apiManager cancelAllRequests];
    self.nextPageToken = nil;
    [self loadVideos];
}

#pragma mark - YouTubeAPIManagerDelegate

- (void)apiManagerDidStartLoading:(YouTubeAPIManager *)manager {
    if ([self.videos count] == 0) {
        [self.loadingIndicator startAnimating];
    }
}

- (void)apiManagerDidFinishLoading:(YouTubeAPIManager *)manager {
    [self.loadingIndicator stopAnimating];
    [self.refreshControl endRefreshing];
}

- (void)apiManager:(YouTubeAPIManager *)manager didReceiveVideos:(NSArray *)videos forCategory:(NSString *)category {
    self.videos = videos;
    self.nextPageToken = manager.nextPageToken;
    [self.tableView reloadData];
    [self prewarmExtract];
}

- (void)prewarmExtract {
    VideoURLCache *uc = [VideoURLCache sharedCache];
    NSInteger count = MIN((NSInteger)[self.videos count], 3);
    for (NSInteger i = 0; i < count; i++) {
        YTVideo *v = [self.videos objectAtIndex:i];
        if ([uc cachedURLForVideoId:v.videoId] || [uc isExtracting:v.videoId]) continue;
        [uc setExtracting:YES forVideoId:v.videoId];
        [self performSelectorInBackground:@selector(extractInBackground:) withObject:v.videoId];
    }
}

- (void)extractInBackground:(NSString *)videoId {
    @autoreleasepool {
        NSString *urlStr = [NSString stringWithFormat:@"%@/api/extract?videoId=%@", VPSProxyBase(), videoId];
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:120];
        NSURLResponse *resp = nil;
        NSError *err = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *url = [json objectForKey:@"url"];
            if (url) {
                [[VideoURLCache sharedCache] cacheURL:url forVideoId:videoId];
            }
        }
        [[VideoURLCache sharedCache] setExtracting:NO forVideoId:videoId];
    }
}

- (void)apiManager:(YouTubeAPIManager *)manager didFailWithError:(NSError *)error {
    [self.loadingIndicator stopAnimating];
    [self.refreshControl endRefreshing];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.videos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    VideoCell *cell = [tableView dequeueReusableCellWithIdentifier:[VideoCell cellIdentifier]];
    if (!cell) {
        cell = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[VideoCell cellIdentifier]];
    }
    if (indexPath.row < (NSInteger)[self.videos count]) {
        [cell configureWithVideo:[self.videos objectAtIndex:indexPath.row]];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)[self.videos count]) {
        YTVideo *video = [self.videos objectAtIndex:indexPath.row];
        VideoPlayerViewController *playerVC = [[VideoPlayerViewController alloc] initWithVideo:video];
        playerVC.relatedVideos = self.videos;
        [self.navigationController pushViewController:playerVC animated:YES];
    }
}

@end

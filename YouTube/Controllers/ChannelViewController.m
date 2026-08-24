#import "ChannelViewController.h"
#import "VideoCell.h"
#import "VideoPlayerViewController.h"

@interface ChannelViewController ()
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@end

@implementation ChannelViewController
- (id)initWithChannelId:(NSString *)channelId title:(NSString *)title {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = title;
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
    if ([self.channelId hasPrefix:@"UC"] && self.channelId.length > 5) {
        [self.apiManager fetchChannelVideos:self.channelId];
    } else if (self.title.length > 0) {
        [self.apiManager searchFromWeb:self.title];
    } else if (self.channelId.length > 0) {
        [self.apiManager searchFromWeb:self.channelId];
    }
}
- (void)apiManager:(YouTubeAPIManager *)m didReceiveVideos:(NSArray *)v forCategory:(NSString *)c {
    if (v.count == 0 && self.title.length > 0) {
        [self.apiManager searchFromWeb:self.title];
        return;
    }
    self.videos = v;
    [self.tableView reloadData];
}
- (void)apiManager:(YouTubeAPIManager *)m didReceiveSearchResults:(NSArray *)v nextPageToken:(NSString *)t {
    self.videos = v;
    [self.tableView reloadData];
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

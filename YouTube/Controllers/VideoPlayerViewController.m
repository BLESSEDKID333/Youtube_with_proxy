#import "VideoPlayerViewController.h"
#import "ChannelViewController.h"
#import "LoginViewController.h"
#import "VideoCell.h"
#import "YTVideo.h"
#import "AuthManager.h"
#import "Constants.h"
#import "DebugLog.h"
#import "VideoURLCache.h"
#import <MediaPlayer/MediaPlayer.h>

@interface VideoPlayerViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate, NSURLConnectionDataDelegate, YouTubeAPIManagerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *playerContainer;
@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, strong) NSMutableData *recvData;
@property (nonatomic, assign) CGFloat infoSectionHeight;
@property (nonatomic, strong) UITableView *relatedTableView;
@property (nonatomic, strong) UIButton *subscribeButton;
@property (nonatomic, assign) BOOL subscribed;
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@end

@implementation VideoPlayerViewController

- (id)initWithVideo:(YTVideo *)video {
    self = [super init];
    if (self) {
        _video = video;
        _relatedVideos = [NSArray array];
        _hasError = NO;
    }
    return self;
}

- (void)loadView {
    UIView *cv = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    cv.backgroundColor = COLOR_WHITE;

    CGFloat w = cv.frame.size.width;
    CGFloat ph = (w * 9.0) / 16.0;

    self.playerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, ph)];
    self.playerContainer.backgroundColor = UIColor.blackColor;
    self.playerContainer.clipsToBounds = YES;
    [cv addSubview:self.playerContainer];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.center = CGPointMake(w / 2, ph / 2 - 10);
    self.spinner.hidesWhenStopped = YES;
    // [self.playerContainer addSubview:self.spinner];
    [self.spinner startAnimating];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, ph / 2 + 12, w, 20)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.text = @"";
    // [self.playerContainer addSubview:self.statusLabel];

    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, ph / 2 - 30, w - 40, 80)];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.textColor = UIColor.whiteColor;
    self.errorLabel.font = [UIFont systemFontOfSize:13];
    self.errorLabel.numberOfLines = 3;
    self.errorLabel.hidden = YES;
    self.errorLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *rt = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(retry)];
    [self.errorLabel addGestureRecognizer:rt];
    [self.playerContainer addSubview:self.errorLabel];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, ph, w, cv.frame.size.height - ph)];
    self.scrollView.backgroundColor = UIColor.whiteColor;
    self.scrollView.alwaysBounceVertical = YES;
    [cv addSubview:self.scrollView];

    self.view = cv;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self layoutInfoSection];
    [self layoutRelatedSection];
    [self loadViaExtractAPI];
    // Load related videos via search
    if (self.video.channelTitle) {
        self.apiManager = [[YouTubeAPIManager alloc] init];
        self.apiManager.delegate = self;
        [self.apiManager searchFromWeb:self.video.channelTitle];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.moviePlayer) {
        [self.moviePlayer pause];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_moviePlayer) {
        [_moviePlayer stop];
        [_moviePlayer.view removeFromSuperview];
    }
}

#pragma mark - Extract API

- (void)loadViaExtractAPI {
    self.recvData = [NSMutableData data];

    VideoURLCache *uc = [VideoURLCache sharedCache];
    // Always fetch fresh URL — YouTube signed URLs expire quickly
    [uc setExtracting:YES forVideoId:self.video.videoId];

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/extract?videoId=%@",
                         VPSProxyBase(), self.video.videoId];
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:120];
    [NSURLConnection connectionWithRequest:req delegate:self];
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)d {
    [self.recvData appendData:d];
}

- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)e {
    [[VideoURLCache sharedCache] setExtracting:NO forVideoId:self.video.videoId];
    [self fail:[e localizedDescription]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)c {
    [[VideoURLCache sharedCache] setExtracting:NO forVideoId:self.video.videoId];
    NSError *je = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:self.recvData options:0 error:&je];
    if (je) { [self fail:[NSString stringWithFormat:@"Bad response: %@", [je localizedDescription]]]; return; }

    NSString *err = [json objectForKey:@"error"];
    if (err) { [self fail:err]; return; }

    NSString *url = [json objectForKey:@"url"];
    if (!url) { [self fail:@"No video URL"]; return; }

    DLog(@"[Player] Got URL for %@: %@", self.video.videoId, [url substringToIndex:MIN(120, [url length])]);
    [[VideoURLCache sharedCache] cacheURL:url forVideoId:self.video.videoId];
    [self playURL:url];
}

- (void)playURL:(NSString *)url {
    self.statusLabel.text = @"Loading...";

    if (self.moviePlayer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }

    NSURL *videoURL = [NSURL URLWithString:url];
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    self.moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
    self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    self.moviePlayer.view.frame = self.playerContainer.bounds;
    self.moviePlayer.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerLoadStateChanged:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerPlaybackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];

    [self.playerContainer insertSubview:self.moviePlayer.view atIndex:0];
    [self.moviePlayer prepareToPlay];
    [self.moviePlayer play];
}

- (void)moviePlayerLoadStateChanged:(NSNotification *)notification {
    if (!self.moviePlayer) return;
    MPMovieLoadState state = self.moviePlayer.loadState;
    DLog(@"[Player] Load state changed: %lu", (unsigned long)state);
    if (state & MPMovieLoadStatePlayable) {
        [self.spinner stopAnimating];
        self.statusLabel.text = @"";
    }
}

- (void)moviePlayerPlaybackDidFinish:(NSNotification *)notification {
    if (!self.moviePlayer) return;
    NSDictionary *userInfo = [notification userInfo];
    NSNumber *reason = [userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason) {
        NSInteger reasonVal = [reason integerValue];
        DLog(@"[Player] Playback finished reason: %ld", (long)reasonVal);
        if (reasonVal == MPMovieFinishReasonPlaybackError) {
            NSError *error = [userInfo objectForKey:@"error"];
            [self fail:error ? [error localizedDescription] : @"Playback error"];
        } else if (reasonVal == MPMovieFinishReasonPlaybackEnded) {
            self.statusLabel.text = @"Finished";
            [self.spinner stopAnimating];
        }
    }
}

- (void)fail:(NSString *)msg {
    [self.spinner stopAnimating];
    self.statusLabel.text = @"";
    self.errorLabel.text = [NSString stringWithFormat:@"%@\nTap to retry", msg];
    self.errorLabel.hidden = NO;
    self.hasError = YES;
}

- (void)retry {
    self.errorLabel.hidden = YES;
    self.hasError = NO;
    [self loadViaExtractAPI];
}

#pragma mark - Info

- (void)layoutInfoSection {
    CGFloat w = self.view.bounds.size.width;
    CGFloat y = 8;

    // Title
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(10, y, w - 20, 0)];
    tl.text = self.video.title;
    tl.font = [UIFont boldSystemFontOfSize:15];
    tl.textColor = [UIColor blackColor];
    tl.numberOfLines = 0;
    [tl sizeToFit];
    tl.frame = CGRectMake(10, y, w - 20, tl.frame.size.height);
    [self.scrollView addSubview:tl];
    y += tl.frame.size.height + 4;

    // Views
    UILabel *vl = [[UILabel alloc] initWithFrame:CGRectMake(10, y, w - 20, 16)];
    NSString *vt = [NSString stringWithFormat:@"%@ views", [self short:self.video.viewCount]];
    if (self.video.publishedAt) vt = [vt stringByAppendingFormat:@"  \u2022  %@", self.video.publishedAt];
    vl.text = vt;
    vl.font = [UIFont systemFontOfSize:12];
    vl.textColor = [UIColor grayColor];
    [self.scrollView addSubview:vl];
    y += 20;

    // Separator
    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep1.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    [self.scrollView addSubview:sep1];
    y += 1;

    // Like / Dislike / Share row
    CGFloat bw = w / 3, bh = 44;
    NSArray *btnTitles = @[
        [NSString stringWithFormat:@"\U0001f44d %@", [self short:self.video.likeCount]],
        [NSString stringWithFormat:@"\U0001f44e %@", self.video.dislikeCount > 0 ? [self short:self.video.dislikeCount] : @""],
        @"Share"
    ];
    SEL actions[] = { @selector(action:), @selector(action:), @selector(action:) };
    for (int i = 0; i < 3; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(i * bw, y, bw, bh);
        [b setTitle:btnTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:13];
        b.tag = 100 + i;
        [b addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        if (i < 2) {
            UIView *div = [[UIView alloc] initWithFrame:CGRectMake(bw - 0.5, 8, 0.5, bh - 16)];
            div.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
            [b addSubview:div];
        }
        [self.scrollView addSubview:b];
    }
    y += bh;

    // Separator
    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep2.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    [self.scrollView addSubview:sep2];
    y += 1;

    // Channel row: tappable name + subscribe button
    UILabel *chLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y + 8, w - 130, 30)];
    chLabel.text = self.video.channelTitle ?: @"";
    chLabel.font = [UIFont systemFontOfSize:14];
    chLabel.textColor = [UIColor darkGrayColor];
    chLabel.userInteractionEnabled = YES;
    [chLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openChannel)]];
    [self.scrollView addSubview:chLabel];

    self.subscribeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.subscribeButton.frame = CGRectMake(w - 118, y + 7, 108, 32);
    [self.subscribeButton setTitle:@"Subscribe" forState:UIControlStateNormal];
    [self.subscribeButton addTarget:self action:@selector(subscribeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.subscribeButton];
    y += 46;

    // Separator
    UIView *sep3 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep3.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    [self.scrollView addSubview:sep3];
    y += 1;

    self.infoSectionHeight = y;
}


- (void)layoutRelatedSection {
    CGFloat w = self.view.bounds.size.width;
    CGFloat ry = self.infoSectionHeight + 10;

    UIView *rh = [[UIView alloc] initWithFrame:CGRectMake(0, ry, w, 30)];
    UILabel *rt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 200, 20)];
    rt.text = @"Related Videos";
    rt.font = [UIFont boldSystemFontOfSize:14];
    rt.textColor = COLOR_DARK_TEXT;
    [rh addSubview:rt];
    [self.scrollView addSubview:rh];

    CGFloat rth = [VideoCell cellHeight] * MIN([self.relatedVideos count], 5);
    self.relatedTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, ry + 30, w, rth)
                                                         style:UITableViewStylePlain];
    self.relatedTableView.delegate = self;
    self.relatedTableView.dataSource = self;
    self.relatedTableView.rowHeight = [VideoCell cellHeight];
    self.relatedTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.relatedTableView.scrollEnabled = NO;
    self.relatedTableView.backgroundColor = COLOR_WHITE;
    [self.scrollView addSubview:self.relatedTableView];

    self.scrollView.contentSize = CGSizeMake(w, ry + 36 + rth + 20);
}

#pragma mark - Helpers

- (NSString *)short:(long long)n {
    if (n >= 1000000) return [NSString stringWithFormat:@"%.1fM", n / 1000000.0];
    if (n >= 1000) return [NSString stringWithFormat:@"%.0fK", n / 1000.0];
    return [NSString stringWithFormat:@"%lld", n];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)io {
    return YES;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat ph = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 420.0 : ((w * 9.0) / 16.0);
    if (ph > h - 150) ph = h - 150;

    self.playerContainer.frame = CGRectMake(0, 0, w, ph);
    if (self.moviePlayer) {
        self.moviePlayer.view.frame = self.playerContainer.bounds;
    }
    self.spinner.center = CGPointMake(w / 2, ph / 2);
    self.statusLabel.frame = CGRectMake(0, ph / 2 + 12, w, 20);
    self.errorLabel.frame = CGRectMake(20, ph / 2 - 30, w - 40, 80);

    self.scrollView.frame = CGRectMake(0, ph, w, h - ph);

    // Re-layout info and related sections for new width
    for (UIView *sub in [self.scrollView subviews]) {
        [sub removeFromSuperview];
    }
    [self layoutInfoSection];
    [self layoutRelatedSection];
}

- (void)openChannel {
    NSString *cid = self.video.channelId;
    NSString *title = self.video.channelTitle;
    if (!cid || cid.length == 0) cid = title;
    if (!cid || cid.length == 0) return;
    ChannelViewController *cvc = [[ChannelViewController alloc] initWithChannelId:cid title:title];
    [self.navigationController pushViewController:cvc animated:YES];
}

- (void)subscribeTapped {
    if (![AuthManager sharedManager].isLoggedIn) {
        LoginViewController *lvc = [[LoginViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:lvc];
        [self presentViewController:nav animated:YES completion:nil];
        return;
    }
    self.subscribed = !self.subscribed;
    NSString *title = self.subscribed ? @"✓ Subscribed" : @"Subscribe";
    [self.subscribeButton setTitle:title forState:UIControlStateNormal];
    if (self.video.channelId.length > 0) {
        if (self.subscribed) {
            [self.apiManager subscribeToChannel:self.video.channelId];
        } else {
            [self.apiManager unsubscribeFromChannel:self.video.channelId];
        }
    }
}

- (void)action:(UIButton *)s {
    switch (s.tag) {
        case 100: { // Like
            if (![AuthManager sharedManager].isLoggedIn) {
                LoginViewController *lvc = [[LoginViewController alloc] init];
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:lvc];
                [self presentViewController:nav animated:YES completion:nil];
            } else {
                self.video.likeCount++;
                [s setTitle:[NSString stringWithFormat:@"👍  %@", [self short:self.video.likeCount]] forState:UIControlStateNormal];
                [self.apiManager likeVideo:self.video.videoId rating:@"LIKE"];
            }
            break;
        }
        case 101: { // Dislike
            if (![AuthManager sharedManager].isLoggedIn) {
                LoginViewController *lvc = [[LoginViewController alloc] init];
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:lvc];
                [self presentViewController:nav animated:YES completion:nil];
            } else {
                self.video.dislikeCount++;
                [s setTitle:[NSString stringWithFormat:@"👎  %@", [self short:self.video.dislikeCount]] forState:UIControlStateNormal];
                [self.apiManager likeVideo:self.video.videoId rating:@"DISLIKE"];
            }
            break;
        }
        case 102: {
            NSString *txt = [NSString stringWithFormat:@"%@\nhttps://youtu.be/%@", self.video.title?:@"", self.video.videoId?:@""];
            [self presentViewController:[[UIActivityViewController alloc] initWithActivityItems:@[txt] applicationActivities:nil] animated:YES completion:nil];
            break;
        }
    }
}

#pragma mark - APIManager delegate

- (void)apiManager:(YouTubeAPIManager *)manager didReceiveSearchResults:(NSArray *)videos nextPageToken:(NSString *)nextPageToken {
    if ([videos count] > 0) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (YTVideo *v in videos) {
            if (![v.videoId isEqualToString:self.video.videoId]) {
                [filtered addObject:v];
            }
        }
        self.relatedVideos = filtered;
        // Resize and reload table
        CGFloat rth = [VideoCell cellHeight] * MIN([self.relatedVideos count], 5);
        CGRect f = self.relatedTableView.frame;
        self.relatedTableView.frame = CGRectMake(f.origin.x, f.origin.y, f.size.width, rth);
        [self.relatedTableView reloadData];
        // Adjust scroll content size
        CGFloat w = self.view.bounds.size.width;
        self.scrollView.contentSize = CGSizeMake(w, f.origin.y + rth + 20);
    }
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return MIN([self.relatedVideos count], 5);
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    VideoCell *c = [tv dequeueReusableCellWithIdentifier:[VideoCell cellIdentifier]];
    if (!c) c = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[VideoCell cellIdentifier]];
    NSInteger idx = ip.row;
    for (NSInteger i = 0; i < (NSInteger)[self.relatedVideos count] && idx == ip.row; i++) {
        if ([[(YTVideo *)self.relatedVideos[i] videoId] isEqualToString:self.video.videoId]) idx++;
    }
    if (idx < (NSInteger)[self.relatedVideos count]) [c configureWithVideo:self.relatedVideos[idx]];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSInteger idx = ip.row;
    for (NSInteger i = 0; i < (NSInteger)[self.relatedVideos count] && idx == ip.row; i++) {
        if ([[(YTVideo *)self.relatedVideos[i] videoId] isEqualToString:self.video.videoId]) idx++;
    }
    if (idx < (NSInteger)[self.relatedVideos count]) {
        VideoPlayerViewController *vc = [[VideoPlayerViewController alloc] initWithVideo:self.relatedVideos[idx]];
        vc.relatedVideos = self.relatedVideos;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end

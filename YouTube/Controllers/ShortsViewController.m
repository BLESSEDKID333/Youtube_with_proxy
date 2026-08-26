//
//  ShortsViewController.m
//  YouTube
//
//  Full-screen vertical YouTube Shorts viewer for iOS 6 (iPhone & iPad)
//

#import "ShortsViewController.h"
#import "YTVideo.h"
#import "YouTubeAPIManager.h"
#import "LocalStreamProxy.h"
#import "Constants.h"
#import "ImageCacheManager.h"
#import "DebugLog.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

@interface ShortsViewController () <UIScrollViewDelegate, YouTubeAPIManagerDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *shortsList;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UIButton *commentButton;
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, assign) BOOL isLiked;
@end

@implementation ShortsViewController

- (id)init {
    self = [super init];
    if (self) {
        self.title = @"Shorts";
        self.shortsList = [NSMutableArray array];
        self.currentIndex = 0;
        self.apiManager = [[YouTubeAPIManager alloc] init];
        self.apiManager.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.clipsToBounds = YES;

    CGRect frame = self.view.bounds;
    self.scrollView = [[UIScrollView alloc] initWithFrame:frame];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.clipsToBounds = YES;
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    // Overlay info
    CGFloat w = frame.size.width;
    CGFloat h = frame.size.height;

    self.authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, h - 120, w - 110, 24)];
    self.authorLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.authorLabel.textColor = [UIColor whiteColor];
    self.authorLabel.font = [UIFont boldSystemFontOfSize:15];
    self.authorLabel.backgroundColor = [UIColor clearColor];
    self.authorLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.authorLabel.layer.shadowOffset = CGSizeMake(1, 1);
    self.authorLabel.layer.shadowOpacity = 0.9;
    [self.view addSubview:self.authorLabel];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, h - 92, w - 110, 40)];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:13];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.titleLabel.layer.shadowOffset = CGSizeMake(1, 1);
    self.titleLabel.layer.shadowOpacity = 0.9;
    [self.view addSubview:self.titleLabel];

    // Right Action Buttons
    self.likeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.likeButton.frame = CGRectMake(w - 80, h - 160, 70, 50);
    self.likeButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [self.likeButton setTitle:@"👍 Like" forState:UIControlStateNormal];
    self.likeButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.likeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.likeButton addTarget:self action:@selector(toggleLike) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.likeButton];

    self.commentButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.commentButton.frame = CGRectMake(w - 80, h - 100, 70, 50);
    self.commentButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [self.commentButton setTitle:@"💬 0" forState:UIControlStateNormal];
    self.commentButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.commentButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.commentButton addTarget:self action:@selector(showComments) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.commentButton];

    [self.spinner startAnimating];
    [self.apiManager fetchShortsFromWeb];
}

- (void)bringOverlaysToFront {
    [self.view bringSubviewToFront:self.authorLabel];
    [self.view bringSubviewToFront:self.titleLabel];
    [self.view bringSubviewToFront:self.likeButton];
    [self.view bringSubviewToFront:self.commentButton];
    [self.view bringSubviewToFront:self.spinner];
}

- (void)toggleLike {
    self.isLiked = !self.isLiked;
    if (self.isLiked) {
        [self.likeButton setTitleColor:[UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.likeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
}

- (void)showComments {
    YTVideo *video = nil;
    if (self.currentIndex >= 0 && self.currentIndex < self.shortsList.count) {
        video = [self.shortsList objectAtIndex:self.currentIndex];
    }
    NSString *msg = video ? [NSString stringWithFormat:@"Comments for \"%@\":\n\n- Awesome Short!\n- 🔥 Great video!\n- Amazing content!", video.title] : @"Comments";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Comments"
                                                    message:msg
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - YouTubeAPIManagerDelegate

- (void)apiManager:(YouTubeAPIManager *)manager didReceiveSearchResults:(NSArray *)videos nextPageToken:(NSString *)nextPageToken {
    [self.spinner stopAnimating];
    if (videos.count > 0) {
        NSInteger startIdx = self.shortsList.count;
        [self.shortsList addObjectsFromArray:videos];

        CGFloat h = self.view.bounds.size.height;
        self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, h * self.shortsList.count);

        if (startIdx == 0) {
            [self playShortAtIndex:0];
        }
    }
}

- (void)apiManager:(YouTubeAPIManager *)manager didReceiveVideos:(NSArray *)videos forCategory:(NSString *)category {
    [self apiManager:manager didReceiveSearchResults:videos nextPageToken:nil];
}

- (void)apiManager:(YouTubeAPIManager *)manager didFailWithError:(NSError *)error {
    [self.spinner stopAnimating];
}

- (void)playShortAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.shortsList.count) return;
    self.currentIndex = index;

    YTVideo *video = [self.shortsList objectAtIndex:index];
    self.titleLabel.text = video.title;
    self.authorLabel.text = video.channelTitle ?: @"@YouTubeShorts";
    
    [self.likeButton setTitle:[NSString stringWithFormat:@"👍 %@", [video formattedLikeCount]] forState:UIControlStateNormal];
    [self.commentButton setTitle:[NSString stringWithFormat:@"💬 %@", [video formattedCommentCount]] forState:UIControlStateNormal];
    self.isLiked = NO;
    [self.likeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    if (self.moviePlayer) {
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }

    [self.spinner startAnimating];
    [self bringOverlaysToFront];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *urlStr = [NSString stringWithFormat:@"%@/api/extract?videoId=%@", VPSProxyBase(), video.videoId];
        NSURL *url = [NSURL URLWithString:urlStr];
        NSData *data = [NSData dataWithContentsOfURL:url];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *streamURL = [json objectForKey:@"url"];
                if (streamURL) {
                    CGFloat h = self.view.bounds.size.height;
                    CGFloat w = self.view.bounds.size.width;
                    CGRect pageFrame = CGRectMake(0, index * h, w, h);

                    NSString *playURL = streamURL;
                    if (VPSBypassEnabled()) {
                        if ([[LocalStreamProxy sharedProxy] startIfNeeded]) {
                            playURL = [[LocalStreamProxy sharedProxy] localURLForRemoteURL:streamURL];
                        }
                    }

                    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:playURL]];
                    self.moviePlayer.controlStyle = MPMovieControlStyleNone;
                    self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
                    self.moviePlayer.shouldAutoplay = YES;
                    self.moviePlayer.view.frame = pageFrame;
                    self.moviePlayer.view.backgroundColor = [UIColor blackColor];
                    self.moviePlayer.view.clipsToBounds = YES;

                    [self.scrollView addSubview:self.moviePlayer.view];
                    [self bringOverlaysToFront];
                    [self.moviePlayer prepareToPlay];
                    [self.moviePlayer play];
                }
            }
        });
    });

    if (index >= (NSInteger)self.shortsList.count - 3 && !self.apiManager.isLoading) {
        [self.apiManager searchFromWeb:@"shorts viral"];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv {
    CGFloat pageHeight = sv.bounds.size.height;
    if (pageHeight <= 0) return;
    NSInteger newIndex = floor((sv.contentOffset.y - pageHeight / 2) / pageHeight) + 1;
    if (newIndex != self.currentIndex && newIndex >= 0 && newIndex < self.shortsList.count) {
        [self playShortAtIndex:newIndex];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.moviePlayer) {
        [self.moviePlayer stop];
    }
}

@end

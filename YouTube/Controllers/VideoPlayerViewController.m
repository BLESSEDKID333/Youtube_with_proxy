#import "VideoPlayerViewController.h"
#import "ChannelViewController.h"
#import "LoginViewController.h"
#import "VideoCell.h"
#import "YTVideo.h"
#import "AuthManager.h"
#import "Constants.h"
#import "DebugLog.h"
#import "VideoURLCache.h"
#import "TLSTrustManager.h"
#import "LocalStreamProxy.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

@interface VideoPlayerViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate, UIActionSheetDelegate, NSURLConnectionDataDelegate, YouTubeAPIManagerDelegate>
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
@property (nonatomic, assign) BOOL usingNativePlayer;
// Custom old-YouTube-style control bar
@property (nonatomic, strong) UIView *controlBar;
@property (nonatomic, strong) CAGradientLayer *controlGradient;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *fullscreenButton;
@property (nonatomic, strong) UIButton *qualityButton;
@property (nonatomic, strong) NSTimer *controlTimer;
@property (nonatomic, assign) BOOL scrubbing;
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, strong) UIView *touchOverlay;
@property (nonatomic, assign) BOOL isFull;
@property (nonatomic, assign) CGRect savedPlayerFrame;
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
    self.spinner.center = CGPointMake(w / 2, ph / 2);
    self.spinner.hidesWhenStopped = YES;
    [self.playerContainer addSubview:self.spinner];
    [self.spinner startAnimating];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, ph / 2 + 12, w, 20)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.text = @"";
    // status text intentionally hidden — spinner alone indicates loading

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

    [self buildControlBarForWidth:w playerHeight:ph];

    self.view = cv;
}

#pragma mark - Custom player controls (old-YouTube style)

- (void)buildControlBarForWidth:(CGFloat)w playerHeight:(CGFloat)ph {
    CGFloat barH = 40;
    self.controlBar = [[UIView alloc] initWithFrame:CGRectMake(0, ph - barH, w, barH)];
    self.controlBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.controlBar.backgroundColor = [UIColor clearColor];

    // Glossy dark gradient bar
    self.controlGradient = [CAGradientLayer layer];
    self.controlGradient.frame = self.controlBar.bounds;
    self.controlGradient.colors = @[
        (id)[UIColor colorWithWhite:0.20 alpha:0.86].CGColor,
        (id)[UIColor colorWithWhite:0.04 alpha:0.92].CGColor
    ];
    [self.controlBar.layer addSublayer:self.controlGradient];

    // thin top highlight
    UIView *hi = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 0.5)];
    hi.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    hi.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.controlBar addSubview:hi];

    // Play / pause
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playPauseButton.frame = CGRectMake(4, 5, 32, 30);
    [self.playPauseButton setImage:[self pauseGlyph] forState:UIControlStateNormal];
    [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.controlBar addSubview:self.playPauseButton];

    // Elapsed
    self.elapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(38, 10, 46, 20)];
    self.elapsedLabel.backgroundColor = [UIColor clearColor];
    self.elapsedLabel.textColor = [UIColor whiteColor];
    self.elapsedLabel.font = [UIFont boldSystemFontOfSize:11];
    self.elapsedLabel.text = @"0:00";
    [self.controlBar addSubview:self.elapsedLabel];

    // Scrubber
    self.scrubber = [[UISlider alloc] initWithFrame:CGRectMake(82, 5, w - 82 - 135, 30)];
    self.scrubber.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if ([self.scrubber respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
        self.scrubber.minimumTrackTintColor = [UIColor colorWithRed:0.85 green:0.0 blue:0.0 alpha:1.0];
        self.scrubber.maximumTrackTintColor = [UIColor colorWithWhite:0.6 alpha:0.7];
    }
    [self.scrubber addTarget:self action:@selector(scrubStart) forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubChanged) forControlEvents:UIControlEventValueChanged];
    [self.scrubber addTarget:self action:@selector(scrubEnd) forControlEvents:UIControlEventTouchUpInside];
    [self.scrubber addTarget:self action:@selector(scrubEnd) forControlEvents:UIControlEventTouchUpOutside];
    [self.controlBar addSubview:self.scrubber];

    // Duration
    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 132, 10, 42, 20)];
    self.durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.durationLabel.backgroundColor = [UIColor clearColor];
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.font = [UIFont boldSystemFontOfSize:11];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.text = @"0:00";
    [self.controlBar addSubview:self.durationLabel];

    // Quality Switcher
    self.qualityButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.qualityButton.frame = CGRectMake(w - 85, 7, 46, 24);
    self.qualityButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.qualityButton setTitle:@"360p" forState:UIControlStateNormal];
    self.qualityButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.qualityButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.qualityButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.qualityButton.layer.borderWidth = 1.0;
    self.qualityButton.layer.cornerRadius = 4.0;
    [self.qualityButton addTarget:self action:@selector(showQualityPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.controlBar addSubview:self.qualityButton];

    // Fullscreen
    self.fullscreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullscreenButton.frame = CGRectMake(w - 34, 5, 30, 30);
    self.fullscreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.fullscreenButton setImage:[self fullscreenGlyph] forState:UIControlStateNormal];
    [self.fullscreenButton addTarget:self action:@selector(toggleFullscreen) forControlEvents:UIControlEventTouchUpInside];
    [self.controlBar addSubview:self.fullscreenButton];

    self.controlBar.hidden = YES; // shown once playback starts

    // Transparent touch-catcher ABOVE the movie view but BELOW the control bar.
    // The MPMoviePlayer view swallows taps, so a gesture on playerContainer stops
    // firing once controls hide — this overlay reliably toggles them back.
    self.touchOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, ph)];
    self.touchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.touchOverlay.backgroundColor = [UIColor clearColor];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    [self.touchOverlay addGestureRecognizer:tap];
    [self.playerContainer addSubview:self.touchOverlay];

    [self.playerContainer addSubview:self.controlBar];
}

- (void)layoutControlGradient {
    self.controlGradient.frame = self.controlBar.bounds;
}

// White play triangle
- (UIImage *)playGlyph {
    CGSize s = CGSizeMake(32, 30);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(11, 8)];
    [p addLineToPoint:CGPointMake(24, 15)];
    [p addLineToPoint:CGPointMake(11, 22)];
    [p closePath];
    [[UIColor whiteColor] setFill];
    [p fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// White pause bars
- (UIImage *)pauseGlyph {
    CGSize s = CGSizeMake(32, 30);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(10, 8, 4, 14));
    UIRectFill(CGRectMake(18, 8, 4, 14));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// Two diagonal expand arrows
- (UIImage *)fullscreenGlyph {
    CGSize s = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(c, 2.0);
    // top-left corner
    CGContextMoveToPoint(c, 6, 12); CGContextAddLineToPoint(c, 6, 6); CGContextAddLineToPoint(c, 12, 6);
    // bottom-right corner
    CGContextMoveToPoint(c, 24, 18); CGContextAddLineToPoint(c, 24, 24); CGContextAddLineToPoint(c, 18, 24);
    CGContextStrokePath(c);
    // diagonal
    CGContextSetLineWidth(c, 1.5);
    CGContextMoveToPoint(c, 7, 7); CGContextAddLineToPoint(c, 13, 13);
    CGContextMoveToPoint(c, 23, 23); CGContextAddLineToPoint(c, 17, 17);
    CGContextStrokePath(c);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (NSString *)formatTime:(NSTimeInterval)t {
    if (t < 0 || t != t) t = 0; // guard NaN
    int total = (int)t;
    int h = total / 3600, m = (total % 3600) / 60, sec = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, sec];
    return [NSString stringWithFormat:@"%d:%02d", m, sec];
}

- (void)startControlTimer {
    [self.controlTimer invalidate];
    self.controlTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
                                                       selector:@selector(updateControls)
                                                       userInfo:nil repeats:YES];
}

- (void)showQualityPicker {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Quality / Разрешение"
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:@"720p HD", @"360p SD", @"240p Low", nil];
    sheet.tag = 999;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet showFromRect:self.qualityButton.bounds inView:self.qualityButton animated:YES];
    } else {
        [sheet showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 999) {
        NSInteger itag = 18;
        NSString *qText = @"360p";
        if (buttonIndex == 0) { itag = 22; qText = @"720p"; }
        else if (buttonIndex == 1) { itag = 18; qText = @"360p"; }
        else if (buttonIndex == 2) { itag = 36; qText = @"240p"; }
        else { return; }

        [self.qualityButton setTitle:qText forState:UIControlStateNormal];
        NSTimeInterval currentTime = self.moviePlayer ? self.moviePlayer.currentPlaybackTime : 0;
        
        [self.spinner startAnimating];
        
        NSString *urlStr = [NSString stringWithFormat:@"%@/api/extract?videoId=%@&itag=%ld&nocache=1&t=%ld", VPSProxyBase(), self.video.videoId, (long)itag, (long)time(NULL)];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]];
            if (data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *streamURL = [json objectForKey:@"url"];
                if (streamURL) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *playURL = streamURL;
                        if (VPSBypassEnabled()) {
                            if ([[LocalStreamProxy sharedProxy] startIfNeeded]) {
                                playURL = [[LocalStreamProxy sharedProxy] localURLForRemoteURL:streamURL];
                            }
                        }
                        [self playURL:playURL startAtTime:currentTime];
                    });
                }
            }
        });
    }
}

- (void)updateControls {
    if (!self.moviePlayer) return;
    NSTimeInterval dur = self.moviePlayer.duration;
    NSTimeInterval cur = self.moviePlayer.currentPlaybackTime;
    if (dur > 0 && dur == dur) {
        self.durationLabel.text = [self formatTime:dur];
        if (!self.scrubbing) {
            self.scrubber.maximumValue = (float)dur;
            self.scrubber.value = (float)cur;
        }
    }
    if (!self.scrubbing) self.elapsedLabel.text = [self formatTime:cur];

    BOOL playing = (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying);
    [self.playPauseButton setImage:(playing ? [self pauseGlyph] : [self playGlyph]) forState:UIControlStateNormal];
}

- (void)togglePlayPause {
    if (!self.moviePlayer) return;
    if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        [self.moviePlayer pause];
        [self.playPauseButton setImage:[self playGlyph] forState:UIControlStateNormal];
    } else {
        [self.moviePlayer play];
        [self.playPauseButton setImage:[self pauseGlyph] forState:UIControlStateNormal];
    }
    [self scheduleAutoHide];
}

- (void)scrubStart { self.scrubbing = YES; }
- (void)scrubChanged { self.elapsedLabel.text = [self formatTime:self.scrubber.value]; }
- (void)scrubEnd {
    if (self.moviePlayer) self.moviePlayer.currentPlaybackTime = self.scrubber.value;
    self.scrubbing = NO;
    [self scheduleAutoHide];
}

- (void)toggleFullscreen {
    if (!self.moviePlayer) return;
    if (self.isFull) { [self exitFullscreen]; } else { [self enterFullscreen]; }
}

// Custom fullscreen: rotate the whole playerContainer (movie view + our control
// bar) into landscape over the key window. Geometry is set instantly (no animated
// bounds/transform, which previously left the video merely rotated at its small
// inline size); only nothing else is animated so it reliably fills the screen.
- (void)enterFullscreen {
    UIWindow *win = [[UIApplication sharedApplication] keyWindow];
    if (!win) return;

    self.savedPlayerFrame = self.playerContainer.frame;
    self.isFull = YES;

    CGRect scr = [[UIScreen mainScreen] bounds];
    CGFloat sw = MIN(scr.size.width, scr.size.height);   // short side (e.g. 320)
    CGFloat sh = MAX(scr.size.width, scr.size.height);    // long side  (e.g. 568)

    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];

    [win addSubview:self.playerContainer];
    self.playerContainer.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    self.playerContainer.bounds = CGRectMake(0, 0, sh, sw); // landscape dims
    self.playerContainer.center = CGPointMake(sw / 2.0, sh / 2.0);

    self.moviePlayer.view.frame = CGRectMake(0, 0, sh, sw);
    self.controlBar.frame = CGRectMake(0, sw - 40, sh, 40);
    self.touchOverlay.frame = CGRectMake(0, 0, sh, sw);
    [self layoutControlGradient];

    [self setControlsVisible:YES animated:NO];
    [self scheduleAutoHide];
}

- (void)exitFullscreen {
    self.isFull = NO;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];

    self.playerContainer.transform = CGAffineTransformIdentity;
    [self.view insertSubview:self.playerContainer atIndex:0];
    self.playerContainer.frame = self.savedPlayerFrame;

    CGFloat w = self.savedPlayerFrame.size.width;
    CGFloat h = self.savedPlayerFrame.size.height;
    self.moviePlayer.view.frame = CGRectMake(0, 0, w, h);
    self.controlBar.frame = CGRectMake(0, h - 40, w, 40);
    self.touchOverlay.frame = CGRectMake(0, 0, w, h);
    [self layoutControlGradient];
}

- (void)toggleControls {
    [self setControlsVisible:!self.controlsVisible animated:YES];
    if (self.controlsVisible) [self scheduleAutoHide];
}

- (void)setControlsVisible:(BOOL)visible animated:(BOOL)animated {
    self.controlsVisible = visible;
    if (visible) self.controlBar.hidden = NO;
    [UIView animateWithDuration:(animated ? 0.25 : 0.0) animations:^{
        self.controlBar.alpha = visible ? 1.0 : 0.0;
    } completion:^(BOOL fin) {
        if (!visible && !self.controlsVisible) self.controlBar.hidden = YES;
    }];
}

- (void)scheduleAutoHide {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoHideControls) object:nil];
    [self performSelector:@selector(autoHideControls) withObject:nil afterDelay:4.0];
}

- (void)autoHideControls {
    if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        [self setControlsVisible:NO animated:YES];
    }
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
    [self.controlTimer invalidate];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
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

    // Native mode (VPS bypass OFF): pull an HLS manifest straight from InnerTube's
    // IOS client — no VPS extractor, no signature deciphering. TLSFix + bundled
    // modern roots make the direct HTTPS call work on iOS 6.
    if (!VPSBypassEnabled()) {
        [self loadViaInnerTubePlayer];
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/extract?videoId=%@",
                         VPSProxyBase(), self.video.videoId];
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:120];
    [NSURLConnection connectionWithRequest:req delegate:self];
}

#pragma mark - Native InnerTube Player (no VPS)

- (void)loadViaInnerTubePlayer {
    [self.spinner startAnimating];
    self.recvData = [NSMutableData data];

    NSURL *url = [NSURL URLWithString:DIRECT_INNERTUBE_PLAYER];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                  timeoutInterval:30];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [req setValue:INNERTUBE_ANDROID_USER_AGENT forHTTPHeaderField:@"User-Agent"];
    [req setValue:INNERTUBE_ANDROID_CLIENT_NAME_HEADER forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [req setValue:INNERTUBE_ANDROID_CLIENT_VERSION forHTTPHeaderField:@"X-YouTube-Client-Version"];

    NSDictionary *payload = @{
        @"videoId": self.video.videoId ?: @"",
        @"contentCheckOk": @YES,
        @"racyCheckOk": @YES,
        @"context": @{
            @"client": @{
                @"clientName": INNERTUBE_ANDROID_CLIENT_NAME,
                @"clientVersion": INNERTUBE_ANDROID_CLIENT_VERSION,
                @"platform": @"MOBILE",
                @"osName": @"Android",
                @"osVersion": INNERTUBE_ANDROID_OS_VERSION,
                @"androidSdkVersion": [NSNumber numberWithInt:INNERTUBE_ANDROID_SDK_VERSION],
                @"hl": INNERTUBE_LANG,
                @"gl": INNERTUBE_COUNTRY
            }
        }
    };
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    [req setHTTPBody:body];

    DLog(@"[Player] Native ANDROID player request for %@", self.video.videoId);
    self.usingNativePlayer = YES;
    [NSURLConnection connectionWithRequest:req delegate:self];
}

- (void)handleNativePlayerResponse {
    NSError *je = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:self.recvData options:0 error:&je];
    if (je || ![json isKindOfClass:[NSDictionary class]]) {
        DLog(@"[Player] native parse fail (%lu bytes)", (unsigned long)self.recvData.length);
        [self fail:@"Bad player response"];
        return;
    }

    // Playability gate
    NSDictionary *status = [json objectForKey:@"playabilityStatus"];
    NSString *playable = [status objectForKey:@"status"];
    if (playable && ![playable isEqualToString:@"OK"]) {
        NSString *reason = [status objectForKey:@"reason"] ?: playable;
        DLog(@"[Player] not playable: %@", reason);
        [self fail:reason];
        return;
    }

    NSDictionary *streaming = [json objectForKey:@"streamingData"];

    // Preferred for ANDROID_VR: a progressive muxed format (itag 18) with a
    // plain, un-ciphered URL — relay it through the local proxy so the media
    // daemon fetches it over plain HTTP from 127.0.0.1 (see LocalStreamProxy).
    NSString *best = [self bestProgressiveURLFromStreaming:streaming];
    if (best.length > 0) {
        DLog(@"[Player] Native progressive URL obtained");
        [[VideoURLCache sharedCache] cacheURL:best forVideoId:self.video.videoId];
        NSString *local = [[LocalStreamProxy sharedProxy] localURLForRemoteURL:best];
        [self playURL:local];
        return;
    }

    // Fallback: adaptive HLS manifest if the client ever provides one. (Segments
    // are absolute HTTPS, so this only works with TLSFix injected into media —
    // kept as a last resort.)
    NSString *hls = [streaming objectForKey:@"hlsManifestUrl"];
    if (hls.length > 0) {
        DLog(@"[Player] Native HLS manifest obtained");
        [[VideoURLCache sharedCache] cacheURL:hls forVideoId:self.video.videoId];
        [self playURL:hls];
        return;
    }

    [self fail:@"No playable stream (native)"];
}

- (NSString *)bestProgressiveURLFromStreaming:(NSDictionary *)streaming {
    NSArray *formats = [streaming objectForKey:@"formats"];
    if (![formats isKindOfClass:[NSArray class]]) return nil;
    NSString *chosen = nil;
    NSInteger chosenHeight = -1;
    for (NSDictionary *f in formats) {
        if (![f isKindOfClass:[NSDictionary class]]) continue;
        NSString *u = [f objectForKey:@"url"]; // only un-ciphered URLs are directly usable
        if (u.length == 0) continue;
        NSInteger h = [[f objectForKey:@"height"] integerValue];
        if (h > chosenHeight) { chosenHeight = h; chosen = u; }
    }
    return chosen;
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)d {
    [self.recvData appendData:d];
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([[TLSTrustManager sharedManager] handleAuthenticationChallenge:challenge forConnection:connection]) {
        return;
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)e {
    [[VideoURLCache sharedCache] setExtracting:NO forVideoId:self.video.videoId];
    [self fail:[e localizedDescription]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)c {
    [[VideoURLCache sharedCache] setExtracting:NO forVideoId:self.video.videoId];

    // Native InnerTube player path parses streamingData instead of the VPS JSON.
    if (self.usingNativePlayer) {
        self.usingNativePlayer = NO;
        [self handleNativePlayerResponse];
        return;
    }

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

- (void)playURL:(NSString *)url startAtTime:(NSTimeInterval)startTime {
    [self.spinner startAnimating];

    if (self.moviePlayer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }

    NSString *playURL = url;
    if (VPSBypassEnabled()) {
        if ([[LocalStreamProxy sharedProxy] startIfNeeded]) {
            playURL = [[LocalStreamProxy sharedProxy] localURLForRemoteURL:url];
        }
    }

    NSURL *videoURL = [NSURL URLWithString:playURL];
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    self.moviePlayer.controlStyle = MPMovieControlStyleNone; // custom old-YouTube controls
    self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    self.moviePlayer.view.frame = self.playerContainer.bounds;
    self.moviePlayer.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.moviePlayer.view.backgroundColor = [UIColor blackColor];
    self.moviePlayer.backgroundView.backgroundColor = [UIColor blackColor];

    if (startTime > 0) {
        self.moviePlayer.initialPlaybackTime = startTime;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerExitedFullscreen:)
                                                 name:MPMoviePlayerDidExitFullscreenNotification
                                               object:self.moviePlayer];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerLoadStateChanged:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerPlaybackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];

    [self.playerContainer insertSubview:self.moviePlayer.view atIndex:0];
    [self.playerContainer bringSubviewToFront:self.controlBar];
    [self.moviePlayer prepareToPlay];
    [self.moviePlayer play];
    [self startControlTimer];
}

- (void)playURL:(NSString *)url {
    [self playURL:url startAtTime:0];
}

- (void)moviePlayerLoadStateChanged:(NSNotification *)notification {
    if (!self.moviePlayer) return;
    MPMovieLoadState state = self.moviePlayer.loadState;
    DLog(@"[Player] Load state changed: %lu", (unsigned long)state);
    if (state & MPMovieLoadStatePlayable) {
        [self.spinner stopAnimating];
        self.statusLabel.text = @"";
        [self layoutControlGradient];
        [self setControlsVisible:YES animated:YES];
        [self scheduleAutoHide];
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

- (void)titleTapped {
    NSString *likesStr = [self.video formattedLikeCount];
    NSString *viewsStr = self.video.formattedViewCount ?: [NSString stringWithFormat:@"%lld views", self.video.viewCount];
    NSString *desc = (self.video.videoDescription && self.video.videoDescription.length > 0) ? self.video.videoDescription : @"No description available.";

    NSString *msg = [NSString stringWithFormat:@"👁 Views: %@\n👍 Likes: %@\n📅 Published: %@\n\n📝 Description:\n%@", viewsStr, likesStr, self.video.publishedAt ?: @"N/A", desc];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.video.title
                                                    message:msg
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Info

- (void)layoutInfoSection {
    CGFloat w = self.view.bounds.size.width;
    CGFloat y = 12;

    // Title
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w - 24, 0)];
    tl.text = self.video.title;
    tl.font = [UIFont boldSystemFontOfSize:16];
    tl.textColor = [UIColor blackColor];
    tl.numberOfLines = 0;
    tl.lineBreakMode = UILineBreakModeWordWrap;
    tl.userInteractionEnabled = YES;
    [tl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleTapped)]];

    CGSize titleSize = [tl sizeThatFits:CGSizeMake(w - 24, CGFLOAT_MAX)];
    tl.frame = CGRectMake(12, y, w - 24, titleSize.height);
    [self.scrollView addSubview:tl];
    y += titleSize.height + 6;

    // Views & Likes summary
    UILabel *vl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w - 24, 18)];
    NSString *vt = [NSString stringWithFormat:@"👁 %@   👍 %@ likes", [self short:self.video.viewCount], [self.video formattedLikeCount]];
    if (self.video.publishedAt) vt = [vt stringByAppendingFormat:@"   •   %@", self.video.publishedAt];
    vl.text = vt;
    vl.font = [UIFont systemFontOfSize:12];
    vl.textColor = [UIColor grayColor];
    vl.userInteractionEnabled = YES;
    [vl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleTapped)]];
    [self.scrollView addSubview:vl];
    y += 24;

    // Separator
    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep1.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    [self.scrollView addSubview:sep1];
    y += 1;

    // Like / Dislike / Share row
    CGFloat bw = w / 3, bh = 48;
    NSArray *btnTitles = @[
        [NSString stringWithFormat:@"👍 %@", [self.video formattedLikeCount]],
        [NSString stringWithFormat:@"👎 %@", self.video.dislikeCount > 0 ? [self short:self.video.dislikeCount] : @""],
        @"↪ Share"
    ];
    SEL actions[] = { @selector(action:), @selector(action:), @selector(action:) };
    for (int i = 0; i < 3; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(i * bw, y, bw, bh);
        [b setTitle:btnTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor colorWithWhite:0.2 alpha:1] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
        b.titleLabel.font = [UIFont systemFontOfSize:13];
        b.tag = 100 + i;
        [b addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        if (i < 2) {
            UIView *div = [[UIView alloc] initWithFrame:CGRectMake(bw - 0.5, 10, 0.5, bh - 20)];
            div.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
            [b addSubview:div];
        }
        [self.scrollView addSubview:b];
    }
    y += bh;

    // Separator
    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep2.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    [self.scrollView addSubview:sep2];
    y += 1;

    // Channel row: tappable channel button + subscribe button
    UIButton *channelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    channelBtn.frame = CGRectMake(12, y + 5, w - 140, 40);
    channelBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [channelBtn setTitle:[NSString stringWithFormat:@"%@  ▶", self.video.channelTitle ?: @"Channel"] forState:UIControlStateNormal];
    [channelBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.35 blue:0.75 alpha:1.0] forState:UIControlStateNormal];
    [channelBtn setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    channelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [channelBtn addTarget:self action:@selector(openChannel) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:channelBtn];

    self.subscribeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.subscribeButton.frame = CGRectMake(w - 122, y + 8, 110, 34);
    [self.subscribeButton setTitle:@"Subscribe" forState:UIControlStateNormal];
    [self.subscribeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.subscribeButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    self.subscribeButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0];
    self.subscribeButton.layer.cornerRadius = 4.0;
    self.subscribeButton.clipsToBounds = YES;
    [self.subscribeButton addTarget:self action:@selector(subscribeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.subscribeButton];
    y += 50;

    // Separator
    UIView *sep3 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 0.5)];
    sep3.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
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
    // While in custom fullscreen the playerContainer lives in the key window with a
    // rotation transform — DON'T let the inline layout reset its frame (that was the
    // bug where fullscreen only rotated the video at its small inline size).
    if (self.isFull) return;

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat ph = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 420.0 : ((w * 9.0) / 16.0);
    if (ph > h - 150) ph = h - 150;

    self.playerContainer.frame = CGRectMake(0, 0, w, ph);
    if (self.moviePlayer) {
        self.moviePlayer.view.frame = self.playerContainer.bounds;
    }
    self.touchOverlay.frame = CGRectMake(0, 0, w, ph);
    self.controlBar.frame = CGRectMake(0, ph - 40, w, 40);
    [self layoutControlGradient];
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

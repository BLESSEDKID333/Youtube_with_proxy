#import "FullScreenPlayerViewController.h"
#import "DebugLog.h"

@interface FullScreenPlayerViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation FullScreenPlayerViewController

- (id)initWithPlayer:(AVPlayer *)player {
    self = [super init];
    if (self) {
        _player = player;
    }
    return self;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return UIInterfaceOrientationIsLandscape(orientation);
}

- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    v.backgroundColor = UIColor.blackColor;
    self.view = v;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    layer.frame = self.view.bounds;
    layer.videoGravity = AVLayerVideoGravityResizeAspect;
    layer.backgroundColor = UIColor.blackColor.CGColor;
    [self.view.layer addSublayer:layer];
    self.playerLayer = layer;

    UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
    done.frame = CGRectMake(12, 12, 72, 36);
    done.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    done.layer.cornerRadius = 4;
    [done setTitle:@"Done" forState:UIControlStateNormal];
    [done setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [done addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:done];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    if (self.player && self.player.rate == 0) {
        [self.player play];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.playerLayer.frame = self.view.bounds;
}

- (void)done {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)dealloc {
    if (_playerLayer) {
        [_playerLayer removeFromSuperlayer];
    }
}

@end

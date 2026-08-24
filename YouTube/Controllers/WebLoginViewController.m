#import "WebLoginViewController.h"
#import "AuthManager.h"
#import "Constants.h"
#import "DebugLog.h"

@interface WebLoginViewController () <UIWebViewDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL checkingCookie;
@property (nonatomic, assign) BOOL loginDetected;
@end

@implementation WebLoginViewController

- (id)init {
    self = [super init];
    if (self) {
        self.title = @"вход";
    }
    return self;
}

- (void)loadView {
    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    contentView.backgroundColor = COLOR_LIGHT_BG;

    self.webView = [[UIWebView alloc]
        initWithFrame:CGRectMake(0, 0, contentView.frame.size.width, contentView.frame.size.height)];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    [contentView addSubview:self.webView];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = contentView.center;
    self.spinner.hidesWhenStopped = YES;
    [contentView addSubview:self.spinner];
    [self.spinner startAnimating];
    
    self.view = contentView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *urlStr;
    if (VPSBypassEnabled()) {
        urlStr = [NSString stringWithFormat:@"%@/google-accounts/ServiceLogin?service=youtube&passive=true&continue=https%%3A%%2F%%2Fm.youtube.com%%2Fsignin%%3Fapp%%3Dmobile%%26action_handle_signin%%3Dtrue&hl=ru", VPSProxyBase()];
    } else {
        urlStr = @"https://accounts.google.com/ServiceLogin?service=youtube";
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self.webView loadRequest:req];

    self.checkingCookie = YES;
    [self performSelector:@selector(checkCookieLoop) withObject:nil afterDelay:2.0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.checkingCookie = NO;
}

- (void)checkCookieLoop {
    if (!self.checkingCookie) return;
    if (self.loginDetected) return;

    NSString *sapisid = [[AuthManager sharedManager] sapisidCookie];
    if ([sapisid length] > 0) {
        DLog(@"[WebLogin] SAPISID cookie found! Logging in...");
        self.loginDetected = YES;
        self.checkingCookie = NO;
        [self loginComplete:sapisid hsid:@"" ssid:@"" apisid:@""];
        return;
    }

    [self performSelector:@selector(checkCookieLoop) withObject:nil afterDelay:1.5];
}

- (void)loginComplete:(NSString *)sapisid hsid:(NSString *)hsid ssid:(NSString *)ssid apisid:(NSString *)apisid {
    DLog(@"[WebLogin] Login complete, SAPISID present");
    [[AuthManager sharedManager] saveSAPISID:sapisid];

    // Set cookies for .youtube.com and .google.com
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *domains = @[@".youtube.com", @".google.com"];

    void (^setCookie)(NSString *, NSString *, NSString *) = ^(NSString *name, NSString *value, NSString *domain) {
        if ([value length] == 0) return;
        NSDictionary *props = @{
            NSHTTPCookieName: name,
            NSHTTPCookieValue: value,
            NSHTTPCookieDomain: domain,
            NSHTTPCookiePath: @"/",
            NSHTTPCookieSecure: @"TRUE",
        };
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:props];
        [storage setCookie:cookie];
    };

    for (NSString *domain in domains) {
        setCookie(@"SAPISID", sapisid, domain);
        setCookie(@"__Secure-3PSAPISID", sapisid, domain);
        if ([hsid length] > 0) {
            setCookie(@"HSID", hsid, domain);
            setCookie(@"__Secure-3PHSID", hsid, domain);
        }
        if ([ssid length] > 0) {
            setCookie(@"SSID", ssid, domain);
            setCookie(@"__Secure-3PSSID", ssid, domain);
        }
        if ([apisid length] > 0) {
            setCookie(@"APISID", apisid, domain);
        }
    }

    [[AuthManager sharedManager] checkLoginState];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loginFailed:(NSString *)reason {
    DLog(@"[WebLogin] Login failed: %@", reason);

    if ([self respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:@"Login Failed"
            message:reason ?: @"Could not sign in. Check credentials."
            delegate:self
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)r
      navigationType:(UIWebViewNavigationType)nt {
    NSString *urlStr = [[r URL] absoluteString];
    DLog(@"[WebLogin] Loading: %@", urlStr);

    if (self.loginDetected) return NO;

    // Handle callback from CGI login
    if ([urlStr hasPrefix:@"ytlogin://"]) {
        NSString *path = [[r URL] host];
        NSString *query = [[r URL] query];

        if ([path isEqualToString:@"success"]) {
            self.loginDetected = YES;

            // Parse token: SAPISID:HSID:SSID:APISID
            NSString *token = nil;
            if (query) {
                NSArray *pairs = [query componentsSeparatedByString:@"&"];
                for (NSString *pair in pairs) {
                    NSArray *kv = [pair componentsSeparatedByString:@"="];
                    if ([kv[0] isEqualToString:@"token"] && [kv count] > 1) {
                        token = [[kv subarrayWithRange:NSMakeRange(1, [kv count] - 1)] componentsJoinedByString:@"="];
                        token = [token stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    }
                }
            }

            if (token) {
                NSArray *parts = [token componentsSeparatedByString:@":"];
                NSString *sapisid = [parts count] > 0 ? parts[0] : @"";
                NSString *hsid = [parts count] > 1 ? parts[1] : @"";
                NSString *ssid = [parts count] > 2 ? parts[2] : @"";
                NSString *apisid = [parts count] > 3 ? parts[3] : @"";

                NSString *s = [sapisid copy];
                NSString *h = [hsid copy];
                NSString *ss = [ssid copy];
                NSString *a = [apisid copy];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self loginComplete:s hsid:h ssid:ss apisid:a];
                });
            }
        } else if ([path isEqualToString:@"failed"]) {
            NSString *reason = @"";
            if (query) {
                NSArray *pairs = [query componentsSeparatedByString:@"&"];
                for (NSString *pair in pairs) {
                    NSArray *kv = [pair componentsSeparatedByString:@"="];
                    if ([kv[0] isEqualToString:@"reason"] && [kv count] > 1) {
                        reason = [[kv subarrayWithRange:NSMakeRange(1, [kv count] - 1)] componentsJoinedByString:@"="];
                        reason = [reason stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    }
                }
            }
            NSString *r = [reason copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loginFailed:r];
            });
        }

        return NO;
    }

    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    [self.spinner stopAnimating];
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    DLog(@"[WebLogin] Load error: %@", [error localizedDescription]);
    [self.spinner stopAnimating];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // dismissed
}

@end

#import "WebLoginViewController.h"
#import "AuthManager.h"
#import "Constants.h"
#import "DebugLog.h"

@interface WebLoginViewController () <UIWebViewDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL checkingCookie;
@property (nonatomic, assign) BOOL loginDetected;
@property (nonatomic, copy) NSString *prevUA;
@property (nonatomic, copy) NSString *mode; // @"vps" or @"direct"
@end

@implementation WebLoginViewController

- (id)initWithMode:(NSString *)mode {
    self = [super init];
    if (self) {
        self.title = @"Sign In";
        _mode = [mode copy] ?: @"vps";
    }
    return self;
}

- (id)init {
    return [self initWithMode:@"vps"];
}

- (void)loadView {
    self.prevUA = [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
    [[NSUserDefaults standardUserDefaults] setObject:
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
                                              forKey:@"UserAgent"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    contentView.backgroundColor = COLOR_LIGHT_BG;

    self.webView = [[UIWebView alloc]
        initWithFrame:CGRectMake(0, 0, contentView.frame.size.width, contentView.frame.size.height)];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [contentView addSubview:self.webView];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = contentView.center;
    self.spinner.hidesWhenStopped = YES;
    [contentView addSubview:self.spinner];
    [self.spinner startAnimating];

    self.view = contentView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered
                                        target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(doneTapped)];

    NSString *urlStr;
    if ([self.mode isEqualToString:@"direct"]) {
        urlStr = @"https://m.youtube.com/signin?app=mobile&action_handle_signin=true";
    } else {
        // VPS CGI login helper
        urlStr = [NSString stringWithFormat:@"%@/cgi-bin/ytlogin?device=%@", VPSProxyBase(), [[AuthManager sharedManager] deviceUUID]];
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self.webView loadRequest:req];

    self.checkingCookie = YES;
    [self performSelector:@selector(checkCookieLoop) withObject:nil afterDelay:2.0];
}

- (void)cancelTapped {
    self.checkingCookie = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneTapped {
    NSString *sapisid = [[AuthManager sharedManager] sapisidCookie];
    if ([sapisid length] > 0 && !self.loginDetected) {
        self.loginDetected = YES;
        self.checkingCookie = NO;
        [self loginComplete:sapisid hsid:@"" ssid:@"" apisid:@""];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.checkingCookie = NO;
    if (self.prevUA) {
        [[NSUserDefaults standardUserDefaults] setObject:self.prevUA forKey:@"UserAgent"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserAgent"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"Login Failed"
        message:reason ?: @"Could not sign in."
        delegate:self
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    [alert show];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)r
      navigationType:(UIWebViewNavigationType)nt {
    NSString *urlStr = [[r URL] absoluteString];
    DLog(@"[WebLogin] Loading: %@", urlStr);

    if (self.loginDetected) return NO;

    if ([urlStr hasPrefix:@"ytlogin://"]) {
        NSString *path = [[r URL] host];
        NSString *query = [[r URL] query];

        if ([path isEqualToString:@"success"]) {
            self.loginDetected = YES;
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

    NSString *urlStr = [[wv.request URL] absoluteString];
    DLog(@"[WebLogin] Finished loading: %@", urlStr);

    // If redirected to main page after Google sign in
    if (urlStr && [urlStr rangeOfString:@"m.youtube.com"].location != NSNotFound &&
        [urlStr rangeOfString:@"/signin"].location == NSNotFound &&
        [urlStr rangeOfString:@"/ServiceLogin"].location == NSNotFound &&
        [urlStr rangeOfString:@"accounts.google.com"].location == NSNotFound) {

        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSString *foundSAPISID = nil;
        for (NSHTTPCookie *c in [storage cookies]) {
            if ([c.name isEqualToString:@"SAPISID"] || [c.name isEqualToString:@"__Secure-3PSAPISID"]) {
                foundSAPISID = c.value;
                break;
            }
        }

        if (foundSAPISID.length > 0) {
            DLog(@"[WebLogin] SAPISID auto-extracted from NSHTTPCookieStorage!");
            self.loginDetected = YES;
            self.checkingCookie = NO;
            [self loginComplete:foundSAPISID hsid:@"" ssid:@"" apisid:@""];
            return;
        }

        NSString *jsCookie = [wv stringByEvaluatingJavaScriptFromString:@"document.cookie"];
        if (jsCookie && [jsCookie rangeOfString:@"SAPISID="].location != NSNotFound) {
            NSArray *parts = [jsCookie componentsSeparatedByString:@";"];
            for (NSString *p in parts) {
                NSString *tp = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([tp hasPrefix:@"SAPISID="]) {
                    foundSAPISID = [tp substringFromIndex:8];
                    break;
                }
            }
            if (foundSAPISID.length > 0) {
                DLog(@"[WebLogin] SAPISID auto-extracted from document.cookie!");
                self.loginDetected = YES;
                self.checkingCookie = NO;
                [self loginComplete:foundSAPISID hsid:@"" ssid:@"" apisid:@""];
                return;
            }
        }

        // Highlight Done button so user can confirm sign in
        self.navigationItem.rightBarButtonItem.title = @"Завершить вход";
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
    }
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    DLog(@"[WebLogin] Load error: %@", [error localizedDescription]);
    [self.spinner stopAnimating];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
}

@end

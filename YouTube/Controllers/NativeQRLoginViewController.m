#import "NativeQRLoginViewController.h"
#import "AuthManager.h"
#import "Constants.h"
#import "TLSTrustManager.h"
#import "DebugLog.h"

@interface NativeQRLoginViewController () <UITextFieldDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UITextField *cookieTextField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) NSMutableData *qrData;
@end

@implementation NativeQRLoginViewController

- (id)init {
    self = [super init];
    if (self) {
        self.title = @"Авторизация / Вход";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStyleBordered
                                         target:self action:@selector(cancelTapped)];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    CGFloat y = 20;

    // Header Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 28)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.text = @"Нативный вход YouTube";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:titleLabel];
    y += 32;

    // Instructions
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 44)];
    subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    subLabel.text = @"Отсканируйте QR-код телефоном или вставьте значение куки SAPISID:";
    subLabel.font = [UIFont systemFontOfSize:13];
    subLabel.textColor = [UIColor darkGrayColor];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.numberOfLines = 2;
    subLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:subLabel];
    y += 50;

    // QR Code Image Container
    CGFloat qrSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 260 : 200;
    UIView *qrBg = [[UIView alloc] initWithFrame:CGRectMake((w - qrSize) / 2.0, y, qrSize, qrSize)];
    qrBg.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    qrBg.backgroundColor = [UIColor whiteColor];
    qrBg.layer.cornerRadius = 8;
    qrBg.layer.shadowColor = [UIColor blackColor].CGColor;
    qrBg.layer.shadowOffset = CGSizeMake(0, 2);
    qrBg.layer.shadowOpacity = 0.15;
    qrBg.layer.shadowRadius = 4;
    [self.scrollView addSubview:qrBg];

    self.qrImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, qrSize - 20, qrSize - 20)];
    self.qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    [qrBg addSubview:self.qrImageView];

    y += qrSize + 20;

    // Fetch QR Code via TLS-enabled request
    NSString *qrUrlStr = @"https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https%3A%2F%2Fm.youtube.com%2Fsignin";
    NSMutableURLRequest *qrReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:qrUrlStr]
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:15];
    self.qrData = [NSMutableData data];
    [NSURLConnection connectionWithRequest:qrReq delegate:self];

    // Cookie input section
    CGFloat fieldW = MIN(w - 40, 500);
    CGFloat fieldX = (w - fieldW) / 2.0;

    UILabel *cookieLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, y, fieldW, 20)];
    cookieLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    cookieLabel.text = @"Значение SAPISID:";
    cookieLabel.font = [UIFont boldSystemFontOfSize:14];
    cookieLabel.textColor = [UIColor blackColor];
    cookieLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:cookieLabel];
    y += 26;

    self.cookieTextField = [[UITextField alloc] initWithFrame:CGRectMake(fieldX, y, fieldW, 44)];
    self.cookieTextField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.cookieTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.cookieTextField.placeholder = @"Вставьте SAPISID или всю строку Cookie";
    self.cookieTextField.font = [UIFont systemFontOfSize:14];
    self.cookieTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.cookieTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.cookieTextField.returnKeyType = UIReturnKeyDone;
    self.cookieTextField.delegate = self;
    [self.scrollView addSubview:self.cookieTextField];
    y += 54;

    self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.submitButton.frame = CGRectMake(fieldX, y, fieldW, 46);
    self.submitButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.submitButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.1 alpha:1.0];
    self.submitButton.layer.cornerRadius = 6;
    [self.submitButton setTitle:@"Войти (Сохранить)" forState:UIControlStateNormal];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.submitButton];
    y += 60;

    self.scrollView.contentSize = CGSizeMake(w, y + 40);
}

#pragma mark - NSURLConnectionDelegate for QR Image

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([[TLSTrustManager sharedManager] handleAuthenticationChallenge:challenge forConnection:connection]) {
        return;
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.qrData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.qrData.length > 0) {
        UIImage *img = [UIImage imageWithData:self.qrData];
        if (img) {
            self.qrImageView.image = img;
        }
    }
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)submitTapped {
    NSString *val = [self.cookieTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (val.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                        message:@"Пожалуйста, введите значение куки SAPISID."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    if ([val rangeOfString:@"SAPISID="].location != NSNotFound) {
        NSArray *parts = [val componentsSeparatedByString:@";"];
        for (NSString *p in parts) {
            NSString *tp = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([tp hasPrefix:@"SAPISID="]) {
                val = [tp substringFromIndex:8];
                break;
            }
        }
    }

    val = [val stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    val = [val stringByReplacingOccurrencesOfString:@"'" withString:@""];
    val = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [[AuthManager sharedManager] saveSAPISID:val];
    [[AuthManager sharedManager] checkLoginState];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Успешно!"
                                                    message:@"Вы успешно вошли в аккаунт!"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    [self submitTapped];
    return YES;
}

@end

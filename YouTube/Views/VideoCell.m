//
//  VideoCell.m
//  YouTube
//
//  Compact list cell — thumbnail left, title/stats right, blue disclosure
//  chevron. Matches the classic iOS 6 YouTube app layout.
//

#import "VideoCell.h"
#import "YTVideo.h"
#import "Constants.h"
#import <QuartzCore/QuartzCore.h>
#import "ImageCacheManager.h"
#import "DebugLog.h"

// Compact row geometry (classic YouTube list)
#define CELL_H          92.0
#define THUMB_X         6.0
#define THUMB_Y         8.0
#define THUMB_W         120.0
#define THUMB_H         76.0
#define TEXT_X          134.0
#define CHEVRON_W       26.0

@implementation VideoCell {
    NSUInteger _requestGeneration;
    UILabel *_likeLabel;
    UILabel *_chevron;
}

+ (NSString *)cellIdentifier { return @"VideoCell"; }
+ (CGFloat)cellHeight { return CELL_H; }

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        self.backgroundColor = COLOR_WHITE;

        // Thumbnail (left)
        _thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(THUMB_X, THUMB_Y, THUMB_W, THUMB_H)];
        _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailImageView.clipsToBounds = YES;
        _thumbnailImageView.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
        _thumbnailImageView.layer.cornerRadius = 2.0;
        [self.contentView addSubview:_thumbnailImageView];

        // Spinner on thumbnail
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.center = CGPointMake(THUMB_X + THUMB_W / 2, THUMB_Y + THUMB_H / 2);
        _activityIndicator.hidesWhenStopped = YES;
        [self.contentView addSubview:_activityIndicator];

        // Duration badge (overlay bottom-right of thumbnail)
        _durationBadge = [[UIView alloc] initWithFrame:CGRectMake(THUMB_X + THUMB_W - 44, THUMB_Y + THUMB_H - 17, 42, 15)];
        _durationBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _durationBadge.layer.cornerRadius = 2.0;
        _durationBadge.clipsToBounds = YES;
        [self.contentView addSubview:_durationBadge];

        _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 42, 15)];
        _durationLabel.textColor = COLOR_WHITE;
        _durationLabel.font = [UIFont boldSystemFontOfSize:10];
        _durationLabel.textAlignment = NSTextAlignmentCenter;
        _durationLabel.backgroundColor = [UIColor clearColor];
        [_durationBadge addSubview:_durationLabel];

        // Title (right, up to 2 lines)
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(TEXT_X, 8, 160, 34)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = COLOR_DARK_TEXT;
        _titleLabel.numberOfLines = 2;
        _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_titleLabel];

        // Like percentage / count (green)
        _likeLabel = [[UILabel alloc] initWithFrame:CGRectMake(TEXT_X, 48, 60, 16)];
        _likeLabel.font = [UIFont boldSystemFontOfSize:12];
        _likeLabel.textColor = [UIColor colorWithRed:0.15 green:0.6 blue:0.15 alpha:1.0];
        _likeLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_likeLabel];

        // Views (gray)
        _viewsLabel = [[UILabel alloc] initWithFrame:CGRectMake(TEXT_X, 48, 160, 16)];
        _viewsLabel.font = [UIFont systemFontOfSize:12];
        _viewsLabel.textColor = COLOR_GRAY_TEXT;
        _viewsLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_viewsLabel];

        // Channel (gray, bottom line)
        _channelLabel = [[UILabel alloc] initWithFrame:CGRectMake(TEXT_X, 68, 160, 16)];
        _channelLabel.font = [UIFont systemFontOfSize:12];
        _channelLabel.textColor = COLOR_GRAY_TEXT;
        _channelLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_channelLabel];

        // dateLabel retained for API compatibility (unused in compact layout)
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.hidden = YES;
        [self.contentView addSubview:_dateLabel];

        // Blue disclosure chevron (far right)
        _chevron = [[UILabel alloc] initWithFrame:CGRectZero];
        _chevron.text = @"\u203a"; // ›
        _chevron.font = [UIFont boldSystemFontOfSize:26];
        _chevron.textColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:1.0];
        _chevron.textAlignment = NSTextAlignmentCenter;
        _chevron.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_chevron];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat textW = w - TEXT_X - CHEVRON_W;

    _thumbnailImageView.frame = CGRectMake(THUMB_X, THUMB_Y, THUMB_W, THUMB_H);
    _activityIndicator.center = CGPointMake(THUMB_X + THUMB_W / 2, THUMB_Y + THUMB_H / 2);
    _durationBadge.frame = CGRectMake(THUMB_X + THUMB_W - 44, THUMB_Y + THUMB_H - 17, 42, 15);

    _titleLabel.frame = CGRectMake(TEXT_X, 8, textW, 34);

    // like + views share the middle line
    CGSize likeSize = [_likeLabel.text sizeWithFont:_likeLabel.font];
    CGFloat likeW = _likeLabel.text.length ? MIN(likeSize.width + 4, 60) : 0;
    _likeLabel.frame = CGRectMake(TEXT_X, 48, likeW, 16);
    _viewsLabel.frame = CGRectMake(TEXT_X + likeW, 48, textW - likeW, 16);

    _channelLabel.frame = CGRectMake(TEXT_X, 68, textW, 16);
    _chevron.frame = CGRectMake(w - CHEVRON_W, 0, CHEVRON_W, CELL_H);
}

- (void)configureWithVideo:(YTVideo *)video {
    if (video.isChannel) {
        self.titleLabel.text = video.title ?: @"Channel";
        _likeLabel.text = @"";
        self.viewsLabel.text = video.subscriberCount ?: @"Channel";
        self.channelLabel.text = @"";
        self.durationBadge.hidden = YES;

        self.thumbnailImageView.image = nil;
        [self.activityIndicator startAnimating];

        NSString *thumbURL = video.thumbnailURL;
        if (!thumbURL || thumbURL.length == 0) {
            thumbURL = [NSString stringWithFormat:@"%@/ytproxy/www.youtube.com/img/channels/c4_avatar.png", VPSProxyBase()];
        }
        _requestGeneration++;
        NSUInteger currentGen = _requestGeneration;
        [[ImageCacheManager sharedCache] loadImageFromURL:thumbURL completion:^(UIImage *image) {
            if (image && _requestGeneration == currentGen) {
                self.thumbnailImageView.image = image;
                [self.activityIndicator stopAnimating];
            }
        }];
        return;
    }

    self.titleLabel.text = video.title ?: @"";
    self.channelLabel.text = video.channelTitle ?: @"";
    self.viewsLabel.text = [NSString stringWithFormat:@"%@ views", [video formattedViewCount]];

    // Like percentage (likes / (likes+dislikes)) when available, else 👍 count.
    if (video.likeCount > 0 && video.dislikeCount > 0) {
        long long total = video.likeCount + video.dislikeCount;
        int pct = (int)((video.likeCount * 100) / total);
        _likeLabel.text = [NSString stringWithFormat:@"\U0001f44d%d%% ", pct];
    } else if (video.likeCount > 0) {
        _likeLabel.text = @"\U0001f44d ";
    } else {
        _likeLabel.text = @"";
    }

    // Duration badge
    NSString *duration = [video formattedDuration];
    if (duration && [duration length] > 0) {
        self.durationBadge.hidden = NO;
        self.durationLabel.text = duration;
    } else {
        self.durationBadge.hidden = YES;
    }

    // Thumbnail — retina screens get the higher-res SD image
    self.thumbnailImageView.image = nil;
    [self.activityIndicator startAnimating];

    BOOL retina = [[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
                  [[UIScreen mainScreen] scale] >= 2.0;
    NSString *thumbURL = retina ? YOUTUBE_THUMBNAIL_URL_MQ(video.videoId)
                                : YOUTUBE_THUMBNAIL_URL(video.videoId);

    _requestGeneration++;
    NSUInteger currentGen = _requestGeneration;
    [[ImageCacheManager sharedCache] loadImageFromURL:thumbURL completion:^(UIImage *image) {
        if (image) {
            if (_requestGeneration != currentGen) return;
            self.thumbnailImageView.image = image;
            [self.activityIndicator stopAnimating];
        }
    }];

    [self setNeedsLayout];
}

- (void)resetCell {
    self.thumbnailImageView.image = nil;
    self.titleLabel.text = @"";
    self.channelLabel.text = @"";
    self.viewsLabel.text = @"";
    _likeLabel.text = @"";
    self.durationLabel.text = @"";
    self.durationBadge.hidden = YES;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self resetCell];
    [self.activityIndicator stopAnimating];
    _requestGeneration++;
}

@end

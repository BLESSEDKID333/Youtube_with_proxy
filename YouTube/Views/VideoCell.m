//
//  VideoCell.m
//  YouTube
//
//  Custom UITableViewCell for video list
//

#import "VideoCell.h"
#import "YTVideo.h"
#import "Constants.h"
#import <QuartzCore/QuartzCore.h>
#import "ImageCacheManager.h"
#import "DebugLog.h"

@implementation VideoCell {
    NSUInteger _requestGeneration;
    UIView *_infoView;
    UIView *_separator;
}

+ (NSString *)cellIdentifier {
    return @"VideoCell";
}

+ (CGFloat)cellHeight {
    return 300.0;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = COLOR_WHITE;

        // Thumbnail
        _thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
        _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailImageView.clipsToBounds = YES;
        _thumbnailImageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        _thumbnailImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_thumbnailImageView];

        // Activity indicator on thumbnail
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.center = CGPointMake(160, 90);
        _activityIndicator.hidesWhenStopped = YES;
        [self.contentView addSubview:_activityIndicator];

        // Duration badge
        _durationBadge = [[UIView alloc] initWithFrame:CGRectMake(258, 153, 57, 22)];
        _durationBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        _durationBadge.layer.cornerRadius = 3.0;
        _durationBadge.clipsToBounds = YES;
        [self.contentView addSubview:_durationBadge];

        _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 0, 53, 22)];
        _durationLabel.textColor = COLOR_WHITE;
        _durationLabel.font = [UIFont boldSystemFontOfSize:11];
        _durationLabel.textAlignment = NSTextAlignmentCenter;
        _durationLabel.backgroundColor = [UIColor clearColor];
        [_durationBadge addSubview:_durationLabel];

        // Info area
        _infoView = [[UIView alloc] initWithFrame:CGRectMake(0, 185, 320, 115)];
        _infoView.backgroundColor = COLOR_WHITE;
        _infoView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_infoView];

        // Title
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 300, 44)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = COLOR_DARK_TEXT;
        _titleLabel.numberOfLines = 2;
        _titleLabel.lineBreakMode = UILineBreakModeWordWrap;
        _titleLabel.backgroundColor = COLOR_WHITE;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_infoView addSubview:_titleLabel];

        // Channel name
        _channelLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 52, 200, 20)];
        _channelLabel.font = [UIFont systemFontOfSize:13];
        _channelLabel.textColor = COLOR_GRAY_TEXT;
        _channelLabel.backgroundColor = COLOR_WHITE;
        _channelLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_infoView addSubview:_channelLabel];

        // Views count
        _viewsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 75, 200, 20)];
        _viewsLabel.font = [UIFont systemFontOfSize:12];
        _viewsLabel.textColor = COLOR_GRAY_TEXT;
        _viewsLabel.backgroundColor = COLOR_WHITE;
        _viewsLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        [_infoView addSubview:_viewsLabel];

        // Date
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(210, 75, 100, 20)];
        _dateLabel.font = [UIFont systemFontOfSize:12];
        _dateLabel.textColor = COLOR_GRAY_TEXT;
        _dateLabel.textAlignment = NSTextAlignmentRight;
        _dateLabel.backgroundColor = COLOR_WHITE;
        _dateLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_infoView addSubview:_dateLabel];

        // Separator line
        _separator = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 300, 0.5)];
        _separator.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_infoView addSubview:_separator];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    _thumbnailImageView.frame = CGRectMake(0, 0, w, 180);
    _activityIndicator.center = CGPointMake(w / 2, 90);
    _durationBadge.frame = CGRectMake(w - 67, 153, 57, 22);
    _infoView.frame = CGRectMake(0, 185, w, 115);
    _titleLabel.frame = CGRectMake(10, 5, w - 20, 44);
    _channelLabel.frame = CGRectMake(10, 52, w - 120, 20);
    _viewsLabel.frame = CGRectMake(10, 75, w - 120, 20);
    _dateLabel.frame = CGRectMake(w - 110, 75, 100, 20);
    _separator.frame = CGRectMake(10, 100, w - 20, 0.5);
}

- (void)configureWithVideo:(YTVideo *)video {
    if (video.isChannel) {
        self.titleLabel.text = video.title ?: @"Channel";
        self.channelLabel.text = @"Channel";
        self.viewsLabel.text = video.subscriberCount ?: @"Channel";
        self.dateLabel.text = @"";
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
    self.viewsLabel.text = [video formattedViewCount];

    // Format published date
    if (video.publishedAt) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        NSDate *date = [formatter dateFromString:video.publishedAt];

        if (date) {
            NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:date];
            if (interval < 3600) {
                self.dateLabel.text = [NSString stringWithFormat:@"%.0fm ago", interval / 60];
            } else if (interval < 86400) {
                self.dateLabel.text = [NSString stringWithFormat:@"%.0fh ago", interval / 3600];
            } else if (interval < 604800) {
                self.dateLabel.text = [NSString stringWithFormat:@"%.0fd ago", interval / 86400];
            } else if (interval < 2592000) {
                self.dateLabel.text = [NSString stringWithFormat:@"%.0fw ago", interval / 604800];
            } else {
                [formatter setDateFormat:@"MMM d, yyyy"];
                self.dateLabel.text = [formatter stringFromDate:date];
            }
        } else {
            self.dateLabel.text = @"";
        }
    }

    // Duration badge
    NSString *duration = [video formattedDuration];
    if (duration && [duration length] > 0) {
        self.durationBadge.hidden = NO;
        self.durationLabel.text = duration;
    } else {
        self.durationBadge.hidden = YES;
    }

    // Load thumbnail — always go through VPS proxy (YouTube domains blocked on home network)
    self.thumbnailImageView.image = nil;
    [self.activityIndicator startAnimating];

    NSString *thumbURL = YOUTUBE_THUMBNAIL_URL(video.videoId);
    DLog(@"[VideoCell] thumbnail via proxy: %@", thumbURL);

    _requestGeneration++;
    NSUInteger currentGen = _requestGeneration;

    [[ImageCacheManager sharedCache] loadImageFromURL:thumbURL completion:^(UIImage *image) {
        DLog(@"[VideoCell] thumbnail callback image=%@ for cell title='%@'", image ? @"OK" : @"nil", self.titleLabel.text);
        if (image) {
            if (_requestGeneration != currentGen) return;
            self.thumbnailImageView.image = image;
            [self.activityIndicator stopAnimating];
        }
    }];
}

- (void)resetCell {
    self.thumbnailImageView.image = nil;
    self.titleLabel.text = @"";
    self.channelLabel.text = @"";
    self.viewsLabel.text = @"";
    self.dateLabel.text = @"";
    self.durationLabel.text = @"";
    self.durationBadge.hidden = YES;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self resetCell];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        self.contentView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    } else {
        self.contentView.backgroundColor = COLOR_WHITE;
    }
}

- (void)dealloc {
    [[ImageCacheManager sharedCache] cancelImageLoads];
}

@end

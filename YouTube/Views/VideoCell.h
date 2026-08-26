//
//  VideoCell.h
//  YouTube
//
//  Custom UITableViewCell for video list
//

#import <UIKit/UIKit.h>

@class YTVideo;

@interface VideoCell : UITableViewCell

@property (nonatomic, strong) UIImageView *thumbnailImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *channelLabel;
@property (nonatomic, strong) UILabel *viewsLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIView *durationBadge;
@property (nonatomic, strong) UILabel *durationLabel;

+ (NSString *)cellIdentifier;
+ (CGFloat)cellHeight;
- (void)configureWithVideo:(YTVideo *)video;
- (void)resetCell;

@end

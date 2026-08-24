#import <UIKit/UIKit.h>
#import "YouTubeAPIManager.h"
#import "YTVideo.h"

@interface ChannelViewController : UITableViewController <YouTubeAPIManagerDelegate>

@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *channelTitle;

- (id)initWithChannelId:(NSString *)channelId title:(NSString *)channelTitle;

@end

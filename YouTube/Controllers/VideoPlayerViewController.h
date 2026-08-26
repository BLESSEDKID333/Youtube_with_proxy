#import <UIKit/UIKit.h>
#import "YTVideo.h"
#import "YouTubeAPIManager.h"

@interface VideoPlayerViewController : UIViewController <YouTubeAPIManagerDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) YTVideo *video;
@property (nonatomic, strong) NSArray *relatedVideos;

- (id)initWithVideo:(YTVideo *)video;

@end

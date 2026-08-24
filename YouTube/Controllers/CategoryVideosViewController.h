//
//  CategoryVideosViewController.h
//  YouTube
//
//  Videos within a specific category
//

#import <UIKit/UIKit.h>
#import "YouTubeAPIManager.h"

@interface CategoryVideosViewController : UITableViewController <YouTubeAPIManagerDelegate>

- (id)initWithCategory:(NSString *)categoryId title:(NSString *)title;

@end

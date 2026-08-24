//
//  SearchViewController.h
//  YouTube
//
//  Video search screen
//

#import <UIKit/UIKit.h>
#import "YouTubeAPIManager.h"

@interface SearchViewController : UITableViewController <YouTubeAPIManagerDelegate, UISearchBarDelegate>

@end

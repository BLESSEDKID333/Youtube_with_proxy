#import "SearchViewController.h"
#import "VideoCell.h"
#import "VideoPlayerViewController.h"
#import "ChannelViewController.h"

@interface SearchViewController () <UISearchBarDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) YouTubeAPIManager *apiManager;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *typeFilterControl;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy) NSString *selectedSortParam;
@end

@implementation SearchViewController

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Search";
        _videos = @[];
        _apiManager = [[YouTubeAPIManager alloc] init];
        _apiManager.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [VideoCell cellHeight];
    CGFloat w = self.view.bounds.size.width;

    // Header container with SearchBar + Type Filter segmented control
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 84)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    headerView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search YouTube";
    [headerView addSubview:self.searchBar];

    self.typeFilterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Videos", @"Channels"]];
    self.typeFilterControl.frame = CGRectMake(10, 48, w - 20, 30);
    self.typeFilterControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.typeFilterControl.selectedSegmentIndex = 0;
    [self.typeFilterControl addTarget:self action:@selector(typeFilterChanged:) forControlEvents:UIControlEventValueChanged];
    [headerView addSubview:self.typeFilterControl];

    self.tableView.tableHeaderView = headerView;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Filter"
        style:UIBarButtonItemStyleBordered
        target:self
        action:@selector(showFilterOptions)];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(w / 2, 220);
    [self.view addSubview:self.loadingIndicator];
}

- (NSString *)currentCombinedParams {
    NSInteger seg = self.typeFilterControl.selectedSegmentIndex;
    NSString *sort = self.selectedSortParam; // nil, "CAI=", "CAM=", "EgQIAhAB", "EgQIAxAB", "EgQIBBAB"
    
    if (seg == 1) { // Videos only
        if ([sort isEqualToString:@"CAI="]) return @"CAIQAQ==";
        if ([sort isEqualToString:@"CAM="]) return @"CAMQAQ==";
        return @"EgIQAQ==";
    } else if (seg == 2) { // Channels only
        if ([sort isEqualToString:@"CAI="]) return @"CAIQAg==";
        if ([sort isEqualToString:@"CAM="]) return @"CAMIQAg==";
        return @"EgIQAg==";
    }
    return sort;
}

- (void)performSearch {
    NSString *q = self.searchBar.text;
    if (!q || q.length == 0) {
        q = @"Trending"; // Fallback search query if search bar is empty
    }
    [self.loadingIndicator startAnimating];
    [self.apiManager searchFromWeb:q params:[self currentCombinedParams]];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    [self performSearch];
}

- (void)typeFilterChanged:(UISegmentedControl *)sender {
    [self performSearch];
}

- (void)showFilterOptions {
    UIActionSheet *sheet = [[UIActionSheet alloc]
        initWithTitle:@"Filter Search Results"
        delegate:self
        cancelButtonTitle:@"Cancel"
        destructiveButtonTitle:nil
        otherButtonTitles:@"Relevance (Default)", @"Upload Date (Newest)", @"View Count (Popular)", @"Uploaded Today", @"Uploaded This Week", @"Uploaded This Month", nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0: self.selectedSortParam = nil; break;          // Relevance
        case 1: self.selectedSortParam = @"CAI="; break;      // Upload Date
        case 2: self.selectedSortParam = @"CAM="; break;      // View Count
        case 3: self.selectedSortParam = @"EgQIAhAB"; break;  // Today
        case 4: self.selectedSortParam = @"EgQIAxAB"; break;  // This Week
        case 5: self.selectedSortParam = @"EgQIBBAB"; break;  // This Month
        default: return;
    }
    [self performSearch];
}

- (void)apiManager:(YouTubeAPIManager *)m didReceiveSearchResults:(NSArray *)v nextPageToken:(NSString *)t {
    [self.loadingIndicator stopAnimating];
    self.videos = v;
    [self.tableView reloadData];
}

- (void)apiManager:(YouTubeAPIManager *)m didFailWithError:(NSError *)e {
    [self.loadingIndicator stopAnimating];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.videos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    VideoCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[VideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    [cell configureWithVideo:self.videos[ip.row]];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    YTVideo *video = self.videos[ip.row];
    if (video.isChannel) {
        NSString *cid = video.channelId ?: video.title;
        ChannelViewController *cvc = [[ChannelViewController alloc] initWithChannelId:cid title:video.title];
        [self.navigationController pushViewController:cvc animated:YES];
    } else {
        VideoPlayerViewController *vp = [[VideoPlayerViewController alloc] initWithVideo:video];
        [self.navigationController pushViewController:vp animated:YES];
    }
}
@end

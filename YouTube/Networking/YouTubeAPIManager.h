//
//  YouTubeAPIManager.h
//  YouTube
//
//  Networking layer using InnerTube Web API via NSURLConnection
//  YouTube Data API v3 — NSURLConnection-based networking
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@class YouTubeAPIManager;

@protocol YouTubeAPIManagerDelegate <NSObject>
@optional
- (void)apiManager:(YouTubeAPIManager *)manager didReceiveVideos:(NSArray *)videos forCategory:(NSString *)category;
- (void)apiManager:(YouTubeAPIManager *)manager didReceiveSearchResults:(NSArray *)videos nextPageToken:(NSString *)nextPageToken;
- (void)apiManager:(YouTubeAPIManager *)manager didReceiveVideoDetails:(YTVideo *)video;
- (void)apiManager:(YouTubeAPIManager *)manager didSubscribeToChannel:(NSString *)channelId subscribed:(BOOL)subscribed;
- (void)apiManager:(YouTubeAPIManager *)manager didRateVideo:(NSString *)videoId rating:(NSString *)rating success:(BOOL)success;
- (void)apiManager:(YouTubeAPIManager *)manager didFailWithError:(NSError *)error;
- (void)apiManagerDidStartLoading:(YouTubeAPIManager *)manager;
- (void)apiManagerDidFinishLoading:(YouTubeAPIManager *)manager;
@end

@interface YouTubeAPIManager : NSObject

@property (nonatomic, weak) id<YouTubeAPIManagerDelegate> delegate;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, copy) NSString *nextPageToken;
@property (nonatomic, copy) NSString *prevPageToken;
@property (nonatomic, strong) NSDictionary *lastResponseJSON;

+ (instancetype)sharedManager;

- (void)fetchTrendingFromWeb;
- (void)searchFromWeb:(NSString *)query;
- (void)searchFromWeb:(NSString *)query params:(NSString *)params;
- (void)fetchCategoryFromWeb:(NSString *)categoryName;
- (void)fetchChannelVideos:(NSString *)channelId;
- (void)fetchSubscriptions;
- (void)fetchShortsFromWeb;
- (void)subscribeToChannel:(NSString *)channelId;
- (void)unsubscribeFromChannel:(NSString *)channelId;
- (void)likeVideo:(NSString *)videoId rating:(NSString *)rating;
- (void)cancelAllRequests;

@end

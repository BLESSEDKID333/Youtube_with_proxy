//
//  YTVideo.h
//  YouTube
//
//  Model for YouTube video
//

#import <Foundation/Foundation.h>

@interface YTVideo : NSObject

@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *videoDescription;
@property (nonatomic, copy) NSString *publishedAt;
@property (nonatomic, copy) NSString *thumbnailURL;
@property (nonatomic, copy) NSString *thumbnailURLMedium;
@property (nonatomic, copy) NSString *thumbnailURLHigh;
@property (nonatomic, assign) long long viewCount;
@property (nonatomic, assign) long long likeCount;
@property (nonatomic, assign) long long dislikeCount;
@property (nonatomic, assign) long long commentCount;
@property (nonatomic, copy) NSString *duration;
@property (nonatomic, assign) BOOL liveBroadcastContent;
@property (nonatomic, assign) BOOL isChannel;
@property (nonatomic, copy) NSString *subscriberCount;

+ (id)videoWithDictionary:(NSDictionary *)dictionary;
+ (id)videoWithWebRenderer:(NSDictionary *)renderer;
+ (NSArray *)videosWithSearchResponse:(NSDictionary *)response;
+ (NSArray *)videosWithDetailsResponse:(NSDictionary *)response;
- (NSString *)formattedViewCount;
- (NSString *)formattedLikeCount;
- (NSString *)formattedCommentCount;
- (NSString *)formattedDuration;
- (NSString *)shortDescription;

@end

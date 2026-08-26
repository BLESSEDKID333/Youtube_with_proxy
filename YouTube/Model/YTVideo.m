//
//  YTVideo.m
//  YouTube
//
//  Model for YouTube video
//

#import "YTVideo.h"
#import "Constants.h"
#import "DebugLog.h"

@implementation YTVideo

+ (id)videoWithDictionary:(NSDictionary *)dictionary {
    YTVideo *video = [[YTVideo alloc] init];

    NSDictionary *snippet = [dictionary objectForKey:@"snippet"];
    NSDictionary *videoIdDict = [dictionary objectForKey:@"id"];

    // Video ID
    if ([videoIdDict isKindOfClass:[NSDictionary class]]) {
        video.videoId = [videoIdDict objectForKey:@"videoId"];
    } else if ([videoIdDict isKindOfClass:[NSString class]]) {
        video.videoId = (NSString *)videoIdDict;
    }

    // Snippet data
    if (snippet) {
        video.title = [snippet objectForKey:@"title"];
        video.channelTitle = [snippet objectForKey:@"channelTitle"];
        video.channelId = [snippet objectForKey:@"channelId"];
        video.videoDescription = [snippet objectForKey:@"description"];
        video.publishedAt = [snippet objectForKey:@"publishedAt"];
        video.liveBroadcastContent = [[snippet objectForKey:@"liveBroadcastContent"] isEqualToString:@"live"];

        // Thumbnails
        NSDictionary *thumbnails = [snippet objectForKey:@"thumbnails"];
        if (thumbnails) {
            NSDictionary *medium = [thumbnails objectForKey:@"medium"];
            NSDictionary *high = [thumbnails objectForKey:@"high"];
            NSDictionary *defaultThumb = [thumbnails objectForKey:@"default"];

            if (high) {
                video.thumbnailURL = [high objectForKey:@"url"];
                video.thumbnailURLMedium = [high objectForKey:@"url"];
            } else if (medium) {
                video.thumbnailURL = [medium objectForKey:@"url"];
                video.thumbnailURLMedium = [medium objectForKey:@"url"];
            } else if (defaultThumb) {
                video.thumbnailURL = [defaultThumb objectForKey:@"url"];
            }
        }
    }

    // Content details (from videos endpoint)
    NSDictionary *contentDetails = [dictionary objectForKey:@"contentDetails"];
    if (contentDetails) {
        video.duration = [contentDetails objectForKey:@"duration"];
        video.liveBroadcastContent = [[contentDetails objectForKey:@"liveBroadcastContent"] isEqualToString:@"live"];
    }

    // Statistics (from videos endpoint)
    NSDictionary *statistics = [dictionary objectForKey:@"statistics"];
    if (statistics) {
        NSString *viewCountStr = [statistics objectForKey:@"viewCount"];
        NSString *likeCountStr = [statistics objectForKey:@"likeCount"];
        NSString *dislikeCountStr = [statistics objectForKey:@"dislikeCount"];
        NSString *commentCountStr = [statistics objectForKey:@"commentCount"];

        video.viewCount = viewCountStr ? [viewCountStr longLongValue] : 0;
        video.likeCount = likeCountStr ? [likeCountStr longLongValue] : 0;
        video.dislikeCount = dislikeCountStr ? [dislikeCountStr longLongValue] : 0;
        video.commentCount = commentCountStr ? [commentCountStr longLongValue] : 0;
    }

    return video;
}

+ (NSArray *)videosWithSearchResponse:(NSDictionary *)response {
    NSMutableArray *result = [NSMutableArray array];
    NSArray *items = [response objectForKey:@"items"];
    if ([items isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dict in items) {
            YTVideo *v = [YTVideo videoWithDictionary:dict];
            if (v && v.videoId) [result addObject:v];
        }
    }
    return result;
}

+ (NSArray *)videosWithDetailsResponse:(NSDictionary *)response {
    return [self videosWithSearchResponse:response];
}

#pragma mark - InnerTube Web Renderer Parser

+ (id)videoWithWebRenderer:(NSDictionary *)renderer {
    if (![renderer isKindOfClass:[NSDictionary class]]) return nil;

    YTVideo *video = [[YTVideo alloc] init];

    // Channel Renderer or Grid Channel Renderer
    NSString *cid = [renderer objectForKey:@"channelId"];
    if (!cid || ![cid isKindOfClass:[NSString class]]) {
        id navEndpoint = [renderer objectForKey:@"navigationEndpoint"];
        if ([navEndpoint isKindOfClass:[NSDictionary class]]) {
            id browseEndpoint = [(NSDictionary *)navEndpoint objectForKey:@"browseEndpoint"];
            if ([browseEndpoint isKindOfClass:[NSDictionary class]]) {
                cid = [(NSDictionary *)browseEndpoint objectForKey:@"browseId"];
            }
        }
    }

    if (cid && [cid isKindOfClass:[NSString class]] && ([cid hasPrefix:@"UC"] || [renderer objectForKey:@"subscriberCountText"] || [renderer objectForKey:@"videoCountText"])) {
        video.isChannel = YES;
        video.channelId = cid;

        id titleObj = [renderer objectForKey:@"title"];
        if ([titleObj isKindOfClass:[NSDictionary class]]) {
            video.title = [(NSDictionary *)titleObj objectForKey:@"simpleText"];
            if (!video.title) {
                NSArray *runs = [(NSDictionary *)titleObj objectForKey:@"runs"];
                if ([runs count] > 0) video.title = [[runs objectAtIndex:0] objectForKey:@"text"];
            }
        }
        if (!video.title) video.title = @"Channel";
        video.channelTitle = video.title;

        id subObj = [renderer objectForKey:@"subscriberCountText"];
        if ([subObj isKindOfClass:[NSDictionary class]]) {
            video.subscriberCount = [(NSDictionary *)subObj objectForKey:@"simpleText"];
            if (!video.subscriberCount) {
                NSArray *runs = [(NSDictionary *)subObj objectForKey:@"runs"];
                if ([runs count] > 0) video.subscriberCount = [[runs objectAtIndex:0] objectForKey:@"text"];
            }
        }

        id thumbObj = [renderer objectForKey:@"thumbnail"];
        if ([thumbObj isKindOfClass:[NSDictionary class]]) {
            NSArray *thumbs = [(NSDictionary *)thumbObj objectForKey:@"thumbnails"];
            if ([thumbs count] > 0) {
                video.thumbnailURL = [[thumbs lastObject] objectForKey:@"url"];
            }
        }
        return video;
    }

    // Video ID — top level (videoId or contentId for lockupViewModel or reelItemRenderer)
    NSString *vid = [renderer objectForKey:@"videoId"];
    if (!vid || ![vid isKindOfClass:[NSString class]]) {
        vid = [renderer objectForKey:@"contentId"];
    }
    if (!vid || ![vid isKindOfClass:[NSString class]]) {
        id inlinePlayer = [renderer objectForKey:@"inlinePlayerEndpoint"];
        if ([inlinePlayer isKindOfClass:[NSDictionary class]]) {
            id playerEndpoint = [(NSDictionary *)inlinePlayer objectForKey:@"watchEndpoint"];
            if ([playerEndpoint isKindOfClass:[NSDictionary class]]) {
                vid = [(NSDictionary *)playerEndpoint objectForKey:@"videoId"];
            }
        }
    }
    if (!vid || ![vid isKindOfClass:[NSString class]]) return nil;
    video.videoId = vid;

    // Title — {"runs": [{"text": "..."}]} or {"simpleText": "..."} or lockupViewModel metadata
    id titleObj = [renderer objectForKey:@"title"];
    if ([titleObj isKindOfClass:[NSDictionary class]]) {
        NSArray *runs = [(NSDictionary *)titleObj objectForKey:@"runs"];
        if ([runs isKindOfClass:[NSArray class]] && [runs count] > 0) {
            video.title = [[runs objectAtIndex:0] objectForKey:@"text"];
        }
        if (!video.title) {
            video.title = [(NSDictionary *)titleObj objectForKey:@"simpleText"];
        }
    }

    if (!video.title) {
        id meta = [renderer objectForKey:@"metadata"];
        if ([meta isKindOfClass:[NSDictionary class]]) {
            id titleHeader = [(NSDictionary *)meta objectForKey:@"title"];
            if ([titleHeader isKindOfClass:[NSDictionary class]]) {
                id contentStr = [(NSDictionary *)titleHeader objectForKey:@"content"];
                if ([contentStr isKindOfClass:[NSString class]]) {
                    video.title = contentStr;
                }
            }
        }
    }

    if (!video.title) video.title = @"YouTube Video";

    // Owner / Channel
    id ownerObj = [renderer objectForKey:@"ownerText"];
    if ([ownerObj isKindOfClass:[NSDictionary class]]) {
        NSArray *runs = [(NSDictionary *)ownerObj objectForKey:@"runs"];
        if ([runs isKindOfClass:[NSArray class]] && [runs count] > 0) {
            NSDictionary *firstRun = [runs objectAtIndex:0];
            video.channelTitle = [firstRun objectForKey:@"text"];
            NSDictionary *navEndpoint = [firstRun objectForKey:@"navigationEndpoint"];
            if ([navEndpoint isKindOfClass:[NSDictionary class]]) {
                NSDictionary *browseEndpoint = [navEndpoint objectForKey:@"browseEndpoint"];
                if ([browseEndpoint isKindOfClass:[NSDictionary class]]) {
                    video.channelId = [browseEndpoint objectForKey:@"browseId"];
                }
            }
        }
    }
    if (!video.channelTitle) {
        id byline = [renderer objectForKey:@"shortBylineText"];
        if ([byline isKindOfClass:[NSDictionary class]]) {
            NSArray *runs = [(NSDictionary *)byline objectForKey:@"runs"];
            if ([runs isKindOfClass:[NSArray class]] && [runs count] > 0) {
                NSDictionary *firstRun = [runs objectAtIndex:0];
                video.channelTitle = [firstRun objectForKey:@"text"];
                NSDictionary *navEndpoint = [firstRun objectForKey:@"navigationEndpoint"];
                if ([navEndpoint isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *browseEndpoint = [navEndpoint objectForKey:@"browseEndpoint"];
                    if ([browseEndpoint isKindOfClass:[NSDictionary class]]) {
                        video.channelId = [browseEndpoint objectForKey:@"browseId"];
                    }
                }
            }
        }
    }

    if (!video.channelTitle) video.channelTitle = @"YouTube";

    // View count
    id viewObj = [renderer objectForKey:@"viewCountText"];
    if ([viewObj isKindOfClass:[NSDictionary class]]) {
        NSString *simpleText = [(NSDictionary *)viewObj objectForKey:@"simpleText"];
        if (simpleText) {
            NSString *cleaned = [simpleText stringByReplacingOccurrencesOfString:@"," withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@" views" withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@" view" withString:@""];
            video.viewCount = [cleaned longLongValue];
        }
    }

    // Thumbnail URL
    id thumbObj = [renderer objectForKey:@"thumbnail"] ?: [renderer objectForKey:@"contentImage"];
    if ([thumbObj isKindOfClass:[NSDictionary class]]) {
        NSArray *thumbs = [(NSDictionary *)thumbObj objectForKey:@"thumbnails"];
        if ([thumbs isKindOfClass:[NSArray class]] && [thumbs count] > 0) {
            video.thumbnailURL = [[thumbs lastObject] objectForKey:@"url"];
            video.thumbnailURLMedium = [[thumbs firstObject] objectForKey:@"url"];
        }
    }
    if (!video.thumbnailURL) {
        video.thumbnailURL = YOUTUBE_THUMBNAIL_URL(video.videoId);
        video.thumbnailURLMedium = YOUTUBE_THUMBNAIL_URL_MQ(video.videoId);
    }

    return video;
}

- (NSString *)formattedViewCount {
    if (self.viewCount <= 0) return @"";
    if (self.viewCount >= 1000000000) {
        return [NSString stringWithFormat:@"%.1fB views", self.viewCount / 1000000000.0];
    } else if (self.viewCount >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM views", self.viewCount / 1000000.0];
    } else if (self.viewCount >= 1000) {
        return [NSString stringWithFormat:@"%.1fK views", self.viewCount / 1000.0];
    }
    return [NSString stringWithFormat:@"%lld views", self.viewCount];
}

- (NSString *)formattedLikeCount {
    if (self.likeCount <= 0) return @"";
    if (self.likeCount >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", self.likeCount / 1000000.0];
    } else if (self.likeCount >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", self.likeCount / 1000.0];
    }
    return [NSString stringWithFormat:@"%lld", self.likeCount];
}

- (NSString *)formattedCommentCount {
    if (self.commentCount <= 0) return @"0";
    if (self.commentCount >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", self.commentCount / 1000000.0];
    } else if (self.commentCount >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", self.commentCount / 1000.0];
    }
    return [NSString stringWithFormat:@"%lld", self.commentCount];
}

- (NSString *)formattedDuration {
    return self.duration ?: @"";
}

- (NSString *)shortDescription {
    if (self.videoDescription.length > 100) {
        return [NSString stringWithFormat:@"%@...", [self.videoDescription substringToIndex:100]];
    }
    return self.videoDescription ?: @"";
}

@end

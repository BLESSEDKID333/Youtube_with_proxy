//
//  YTVideo.m
//  YouTube
//
//  Model for YouTube video
//

#import "YTVideo.h"
#import "Constants.h"
#import "DebugLog.h"

static long long parseShortCount(NSString *str) {
    if (!str) return 0;
    NSString *s = [str stringByReplacingOccurrencesOfString:@"," withString:@""];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    long long multiplier = 1;
    if ([s hasSuffix:@"B"]) { multiplier = 1000000000; s = [s substringToIndex:[s length] - 1]; }
    else if ([s hasSuffix:@"M"]) { multiplier = 1000000; s = [s substringToIndex:[s length] - 1]; }
    else if ([s hasSuffix:@"K"]) { multiplier = 1000; s = [s substringToIndex:[s length] - 1]; }
    return (long long)([s doubleValue] * multiplier);
}

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

#pragma mark - InnerTube Web Renderer Parser

+ (id)videoWithWebRenderer:(NSDictionary *)renderer {
    if (![renderer isKindOfClass:[NSDictionary class]]) return nil;

    YTVideo *video = [[YTVideo alloc] init];

    // Channel Renderer
    NSString *cid = [renderer objectForKey:@"channelId"];
    if (cid && [cid isKindOfClass:[NSString class]]) {
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

    // Video ID — top level
    NSString *vid = [renderer objectForKey:@"videoId"];
    if (!vid || ![vid isKindOfClass:[NSString class]]) return nil;
    video.videoId = vid;

    // Title — {"runs": [{"text": "..."}]} or {"simpleText": "..."}
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

    // Owner / Channel — {"runs": [{"text": "...", "navigationEndpoint": {"browseEndpoint": {"browseId": "UC..."}}}]}
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

    // View count — {"simpleText": "1,234,567 views"} or {"runs": [...]}
    id viewObj = [renderer objectForKey:@"viewCountText"];
    if ([viewObj isKindOfClass:[NSDictionary class]]) {
        NSString *simpleText = [(NSDictionary *)viewObj objectForKey:@"simpleText"];
        if (simpleText) {
            // Parse "1,234,567 views" to long long
            NSString *cleaned = [simpleText stringByReplacingOccurrencesOfString:@"," withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@" views" withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@" view" withString:@""];
            video.viewCount = [cleaned longLongValue];
        }
    }
    if (video.viewCount == 0) {
        id shortViewObj = [renderer objectForKey:@"shortViewCountText"];
        if ([shortViewObj isKindOfClass:[NSDictionary class]]) {
            NSArray *runs = [(NSDictionary *)shortViewObj objectForKey:@"runs"];
            if ([runs isKindOfClass:[NSArray class]] && [runs count] > 0) {
                NSString *numStr = [[runs objectAtIndex:0] objectForKey:@"text"];
                NSString *cleaned = [numStr stringByReplacingOccurrencesOfString:@"," withString:@""];
                video.viewCount = [cleaned longLongValue];
            }
        }
    }

    // Published time — {"simpleText": "2 days ago"}
    id pubObj = [renderer objectForKey:@"publishedTimeText"];
    if ([pubObj isKindOfClass:[NSDictionary class]]) {
        video.publishedAt = [(NSDictionary *)pubObj objectForKey:@"simpleText"];
    }

    // Duration — {"simpleText": "10:30"}
    id lenObj = [renderer objectForKey:@"lengthText"];
    if ([lenObj isKindOfClass:[NSDictionary class]]) {
        video.duration = [(NSDictionary *)lenObj objectForKey:@"simpleText"];
    }

    // Like/Dislike counts from topLevelButtons
    id buttons = [renderer objectForKey:@"topLevelButtons"];
    if ([buttons isKindOfClass:[NSArray class]]) {
        for (id btnObj in (NSArray *)buttons) {
            id toggleBtn = [btnObj objectForKey:@"toggleButtonRenderer"];
            if ([toggleBtn isKindOfClass:[NSDictionary class]]) {
                id icon = [(NSDictionary *)toggleBtn objectForKey:@"defaultIcon"];
                id text = [(NSDictionary *)toggleBtn objectForKey:@"defaultText"];
                NSDictionary *defaultTextDict = nil;
                if ([text isKindOfClass:[NSDictionary class]]) {
                    defaultTextDict = (NSDictionary *)text;
                }
                if ([icon isKindOfClass:[NSDictionary class]]) {
                    NSString *iconType = [(NSDictionary *)icon objectForKey:@"iconType"];
                    NSString *countStr = [defaultTextDict objectForKey:@"simpleText"];
                    if ([iconType isEqualToString:@"LIKE"] && countStr) {
                        video.likeCount = parseShortCount(countStr);
                    } else if ([iconType isEqualToString:@"DISLIKE"] && countStr) {
                        video.dislikeCount = parseShortCount(countStr);
                    }
                }
            }
        }
    }

    // Description snippet (from search results)
    id descObj = [renderer objectForKey:@"detailedMetadataSnippets"];
    if ([descObj isKindOfClass:[NSArray class]] && [(NSArray *)descObj count] > 0) {
        NSDictionary *snippet = [(NSArray *)descObj objectAtIndex:0];
        id snippetText = [snippet objectForKey:@"snippetText"];
        if ([snippetText isKindOfClass:[NSDictionary class]]) {
            NSArray *runs = [(NSDictionary *)snippetText objectForKey:@"runs"];
            if ([runs isKindOfClass:[NSArray class]]) {
                NSMutableString *desc = [NSMutableString string];
                for (NSDictionary *run in runs) {
                    NSString *t = [run objectForKey:@"text"];
                    if (t) [desc appendString:t];
                }
                video.videoDescription = desc;
            }
        }
    }
    if (!video.videoDescription) {
        id shortDesc = [renderer objectForKey:@"descriptionSnippet"];
        if ([shortDesc isKindOfClass:[NSDictionary class]]) {
            NSArray *runs = [(NSDictionary *)shortDesc objectForKey:@"runs"];
            if ([runs isKindOfClass:[NSArray class]]) {
                NSMutableString *desc = [NSMutableString string];
                for (NSDictionary *run in runs) {
                    NSString *t = [run objectForKey:@"text"];
                    if (t) [desc appendString:t];
                }
                video.videoDescription = desc;
            }
        }
    }

    // Thumbnails — {"thumbnails": [{"url": "...", "width": N, "height": N}]}
    id thumbObj = [renderer objectForKey:@"thumbnail"];
    if ([thumbObj isKindOfClass:[NSDictionary class]]) {
        NSArray *thumbs = [(NSDictionary *)thumbObj objectForKey:@"thumbnails"];
        if ([thumbs isKindOfClass:[NSArray class]] && [thumbs count] > 0) {
            // Get the largest thumbnail
            NSDictionary *best = nil;
            NSInteger bestArea = 0;
            for (NSDictionary *t in thumbs) {
                if (![t isKindOfClass:[NSDictionary class]]) continue;
                NSInteger w = [[t objectForKey:@"width"] integerValue];
                NSInteger h = [[t objectForKey:@"height"] integerValue];
                if (w * h > bestArea) {
                    bestArea = w * h;
                    best = t;
                }
            }
            if (best) {
                video.thumbnailURL = [best objectForKey:@"url"];
                video.thumbnailURLMedium = video.thumbnailURL;
                video.thumbnailURLHigh = video.thumbnailURL;
            }
        }
    }

    // Fallback thumbnails using video ID
    if (!video.thumbnailURL && video.videoId) {
        video.thumbnailURL = YOUTUBE_THUMBNAIL_URL(video.videoId);
        video.thumbnailURLMedium = YOUTUBE_THUMBNAIL_URL_MQ(video.videoId);
        video.thumbnailURLHigh = YOUTUBE_THUMBNAIL_URL_SD(video.videoId);
    }

    DLog(@"[YTVideo] Parsed videoId='%@' title='%@' thumb='%@' channel='%@' views=%lld",
         video.videoId, video.title, video.thumbnailURL, video.channelTitle, video.viewCount);

    return video;
}

+ (NSArray *)videosWithSearchResponse:(NSDictionary *)response {
    DLog(@"[YTVideo] videosWithSearchResponse called, items=%@", [response objectForKey:@"items"] ? @"present" : @"nil");
    NSMutableArray *videos = [NSMutableArray array];
    NSArray *items = [response objectForKey:@"items"];

    if (items && [items isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in items) {
            NSString *kind = [[[item objectForKey:@"id"] objectForKey:@"kind"] stringByReplacingOccurrencesOfString:@"youtube#" withString:@""];
            if ([kind isEqualToString:@"video"]) {
                YTVideo *video = [YTVideo videoWithDictionary:item];
                if (video.videoId) {
                    [videos addObject:video];
                }
            }
        }
    }

    return [NSArray arrayWithArray:videos];
}

+ (NSArray *)videosWithDetailsResponse:(NSDictionary *)response {
    NSMutableArray *videos = [NSMutableArray array];
    NSArray *items = [response objectForKey:@"items"];

    if (items && [items isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in items) {
            YTVideo *video = [YTVideo videoWithDictionary:item];
            if (video.videoId) {
                [videos addObject:video];
            }
        }
    }

    return [NSArray arrayWithArray:videos];
}

- (NSString *)formattedViewCount {
    if (self.viewCount >= 1000000000) {
        return [NSString stringWithFormat:@"%.1fB views", self.viewCount / 1000000000.0];
    } else if (self.viewCount >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM views", self.viewCount / 1000000.0];
    } else if (self.viewCount >= 1000) {
        return [NSString stringWithFormat:@"%.1fK views", self.viewCount / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%lld views", self.viewCount];
    }
}

- (NSString *)formattedDuration {
    if (!self.duration) return @"";

    // Already in human-readable format (from InnerTube web, e.g. "10:30", "1:02:15")
    if (![self.duration hasPrefix:@"PT"] && ![self.duration hasPrefix:@"P"]) {
        return self.duration;
    }

    // Parse ISO 8601 duration (PT#H#M#S)
    NSString *duration = self.duration;
    duration = [duration stringByReplacingOccurrencesOfString:@"PT" withString:@""];
    duration = [duration stringByReplacingOccurrencesOfString:@"P" withString:@""];

    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    // Extract hours
    NSRange hRange = [duration rangeOfString:@"H"];
    if (hRange.location != NSNotFound) {
        NSString *hoursStr = [duration substringToIndex:hRange.location];
        hours = [hoursStr intValue];
        duration = [duration substringFromIndex:hRange.location + 1];
    }

    // Extract minutes
    NSRange mRange = [duration rangeOfString:@"M"];
    if (mRange.location != NSNotFound) {
        NSString *minutesStr = [duration substringToIndex:mRange.location];
        minutes = [minutesStr intValue];
        duration = [duration substringFromIndex:mRange.location + 1];
    }

    // Extract seconds
    NSRange sRange = [duration rangeOfString:@"S"];
    if (sRange.location != NSNotFound) {
        NSString *secondsStr = [duration substringToIndex:sRange.location];
        seconds = [secondsStr intValue];
    }

    if (hours > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    }
}

- (NSString *)shortDescription {
    if (!self.videoDescription) return @"";
    if ([self.videoDescription length] > 200) {
        return [[self.videoDescription substringToIndex:197] stringByAppendingString:@"..."];
    }
    return self.videoDescription;
}

@end

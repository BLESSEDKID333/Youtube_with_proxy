//
//  Constants.h
//  YouTube
//
//  Native YouTube Client for iOS 6
//

#ifndef YouTube_Constants_h
#define YouTube_Constants_h

// ==================== VPS BYPASS TOGGLE ====================
#define VPS_BYPASS_KEY          @"vps_bypass_enabled"
#define VPS_PROXY_KEY           @"vps_proxy_base"
#define VPS_PROXY_DEFAULT       @"http://192.144.13.102"

static inline BOOL VPSBypassEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:VPS_BYPASS_KEY];
}

static inline NSString * VPSProxyBase(void) {
    return VPS_PROXY_DEFAULT;
}

#define VPS_MOBILE_BASE         [NSString stringWithFormat:@"%@:9090", VPSProxyBase()]

// ==================== INNERTUBE WEB API ====================
#define INNERTUBE_API_KEY    @"AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"

// Reverse proxy on VPS (saved in NSUserDefaults under VPS_PROXY_KEY)

// InnerTube Endpoints (VPS proxy)
#define VPS_INNERTUBE_BASE   [NSString stringWithFormat:@"%@/youtubei/v1", VPSProxyBase()]

// InnerTube Endpoints (direct)
#define DIRECT_INNERTUBE_BASE   @"https://www.youtube.com/youtubei/v1"

// Select based on bypass setting
#define INNERTUBE_BASE       (VPSBypassEnabled() ? VPS_INNERTUBE_BASE : DIRECT_INNERTUBE_BASE)
#define INNERTUBE_BROWSE     [NSString stringWithFormat:@"%@/browse", INNERTUBE_BASE]
#define INNERTUBE_SEARCH     [NSString stringWithFormat:@"%@/search", INNERTUBE_BASE]
#define INNERTUBE_NEXT       [NSString stringWithFormat:@"%@/next", INNERTUBE_BASE]
#define INNERTUBE_PLAYER     [NSString stringWithFormat:@"%@/player", INNERTUBE_BASE]
#define INNERTUBE_SUBSCRIBE   [NSString stringWithFormat:@"%@/subscription/subscribe", INNERTUBE_BASE]
#define INNERTUBE_UNSUBSCRIBE [NSString stringWithFormat:@"%@/subscription/unsubscribe", INNERTUBE_BASE]
#define INNERTUBE_LIKE        [NSString stringWithFormat:@"%@/like/like", INNERTUBE_BASE]
#define INNERTUBE_DISLIKE     [NSString stringWithFormat:@"%@/like/dislike", INNERTUBE_BASE]
#define INNERTUBE_REMOVELIKE  [NSString stringWithFormat:@"%@/like/removelike", INNERTUBE_BASE]

// InnerTube Client Context
#define INNERTUBE_CLIENT_NAME @"WEB"
#define INNERTUBE_CLIENT_NAME_HEADER @"1"
#define INNERTUBE_CLIENT_VERSION @"2.20260727.01.00"
#define INNERTUBE_LANG @"en"
#define INNERTUBE_COUNTRY @"US"

// ==================== VIDEO CATEGORIES ====================
#define CATEGORY_ID_MUSIC       @"10"
#define CATEGORY_ID_GAMING      @"20"
#define CATEGORY_ID_MOVIES      @"1"
#define CATEGORY_ID_NEWS        @"25"
#define CATEGORY_ID_SPORTS      @"17"
#define CATEGORY_ID_EDUCATION   @"27"
#define CATEGORY_ID_COMEDY      @"23"
#define CATEGORY_ID_ENTERTAINMENT @"24"
#define CATEGORY_ID_TECHNOLOGY  @"28"
#define CATEGORY_ID_POLITICS    @"26"

// ==================== APP SETTINGS ====================
#define MAX_RESULTS_DEFAULT     25
#define MAX_RESULTS_SEARCH      50
#define CACHE_DURATION          300.0
#define THUMBNAIL_WIDTH         320
#define THUMBNAIL_HEIGHT        180

// ==================== UI CONSTANTS ====================
#define CELL_HEIGHT             290.0
#define THUMBNAIL_TAG           1000
#define TITLE_LABEL_TAG         1001
#define CHANNEL_LABEL_TAG       1002
#define VIEWS_LABEL_TAG         1003
#define DATE_LABEL_TAG          1004
#define ACTIVITY_TAG            1005

// ==================== NOTIFICATIONS ====================
#define NOTIFICATION_VIDEO_LOADED   @"VideoLoadedNotification"
#define NOTIFICATION_API_ERROR      @"APIErrorNotification"
#define NOTIFICATION_NETWORK_ERROR  @"NetworkErrorNotification"

// ==================== VIDEO EXTRACT API ====================
#define VPS_EXTRACT_API         [NSString stringWithFormat:@"%@/api/extract", VPSProxyBase()]
#define DIRECT_GET_VIDEO_INFO(vid) [NSString stringWithFormat:@"https://www.youtube.com/get_video_info?video_id=%@&el=embedded&hl=en", vid]

// ==================== URLs ====================
#define YOUTUBE_WATCH_URL       @"https://m.youtube.com/watch?v="
#define YOUTUBE_THUMBNAIL_URL(vid) (VPSBypassEnabled() \
    ? [NSString stringWithFormat:@"%@/vi/%@/hqdefault.jpg", VPSProxyBase(), vid] \
    : [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/hqdefault.jpg", vid])
#define YOUTUBE_THUMBNAIL_URL_SD(vid) (VPSBypassEnabled() \
    ? [NSString stringWithFormat:@"%@/vi/%@/sddefault.jpg", VPSProxyBase(), vid] \
    : [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/sddefault.jpg", vid])
#define YOUTUBE_THUMBNAIL_URL_MQ(vid) (VPSBypassEnabled() \
    ? [NSString stringWithFormat:@"%@/vi/%@/mqdefault.jpg", VPSProxyBase(), vid] \
    : [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", vid])

// ==================== COLOR THEME (YouTube Red) ====================
#define COLOR_YOUTUBE_RED       [UIColor colorWithRed:255.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define COLOR_DARK_BG           [UIColor colorWithRed:35.0/255.0 green:35.0/255.0 blue:35.0/255.0 alpha:1.0]
#define COLOR_LIGHT_BG          [UIColor colorWithRed:242.0/255.0 green:242.0/255.0 blue:242.0/255.0 alpha:1.0]
#define COLOR_WHITE             [UIColor whiteColor]
#define COLOR_BLACK             [UIColor blackColor]
#define COLOR_GRAY_TEXT         [UIColor grayColor]
#define COLOR_GRAY              [UIColor colorWithRed:128.0/255.0 green:128.0/255.0 blue:128.0/255.0 alpha:1.0]
#define COLOR_DARK_TEXT         [UIColor colorWithRed:51.0/255.0 green:51.0/255.0 blue:51.0/255.0 alpha:1.0]

#endif

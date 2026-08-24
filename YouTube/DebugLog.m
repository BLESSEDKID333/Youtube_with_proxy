//
//  DebugLog.m
//  YouTube
//
//  File-based debug logging utility
//

#import "DebugLog.h"
#import <UIKit/UIKit.h>

static NSFileHandle *gLogFileHandle = nil;
static NSDateFormatter *gLogDateFormatter = nil;

void DebugLogInit(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [paths objectAtIndex:0];
    NSString *logPath = [docsDir stringByAppendingPathComponent:@"debug.log"];

    // Remove old log
    [[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];

    gLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];

    gLogDateFormatter = [[NSDateFormatter alloc] init];
    [gLogDateFormatter setDateFormat:@"HH:mm:ss.SSS"];

    DLog(@"=== YouTube Debug Log Started ===");
    DLog(@"Device: %@ %@", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]);
    DLog(@"Model: %@", [[UIDevice currentDevice] model]);
    DLog(@"Documents dir: %@", docsDir);
}

NSString *DebugLogPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"debug.log"];
}

NSString *DebugLogContents(void) {
    NSString *path = DebugLogPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return @"(no log data)";
}

void WriteCrashReport(NSException *exception) {
    NSString *path = DebugLogPath();
    NSMutableString *crash = [NSMutableString string];
    [crash appendString:@"\n\n========== CRASH REPORT ==========\n"];
    [crash appendFormat:@"Name: %@\n", [exception name]];
    [crash appendFormat:@"Reason: %@\n", [exception reason]];
    NSString *symbols = [exception callStackSymbols] ? [[exception callStackSymbols] componentsJoinedByString:@"\n"] : @"(no symbols)";
    [crash appendFormat:@"Symbols: %@\n", symbols];
    [crash appendString:@"==================================\n"];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[crash dataUsingEncoding:NSUTF8StringEncoding]];
        [fh synchronizeFile];
        [fh closeFile];
    }
}

void DLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // NSLog output (visible in device console via libimobiledevice)
    NSLog(@"[YT] %@", message);

    // Write to file
    if (gLogFileHandle && gLogDateFormatter) {
        NSString *timestamp = [gLogDateFormatter stringFromDate:[NSDate date]];
        NSString *logLine = [NSString stringWithFormat:@"%@ %@\n", timestamp, message];
        @try {
            [gLogFileHandle seekToEndOfFile];
            [gLogFileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
            [gLogFileHandle synchronizeFile];
        }
        @catch (NSException *e) {
            // Silently fail if file write fails
        }
    }
}

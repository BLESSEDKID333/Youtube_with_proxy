//
//  DebugLog.h
//  YouTube
//
//  File-based debug logging utility
//  Logs are written to Documents/debug.log and readable via iTunes File Sharing
//

#import <Foundation/Foundation.h>

// Log a message to both NSLog and file
void DLog(NSString *format, ...);

// Initialize logging (call from AppDelegate)
void DebugLogInit(void);

// Get the log file path
NSString *DebugLogPath(void);

// Get all logged content (for display in UI)
NSString *DebugLogContents(void);

// Write a crash report
void WriteCrashReport(NSException *exception);

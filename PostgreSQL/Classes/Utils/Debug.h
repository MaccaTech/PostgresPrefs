//
//  Debug.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 19/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#ifndef PostgreSQL_Debug_h
#define PostgreSQL_Debug_h

#ifdef DEBUG
#
CG_INLINE void DebugLog(NSString *logFile, Class clazz, const char *func, NSString* fmt, ...)
{
    // Get log message args
    va_list argList;
    va_start(argList, fmt);
    NSString* msg = [[NSString alloc] initWithFormat:fmt arguments:argList];
    va_end(argList);
    
    // Format
    static NSDateFormatter *dateFormatter = nil;
    if (!dateFormatter) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        dateFormatter = formatter;
    }
    NSString *formattedMsg =
    [NSString stringWithFormat:
     @"\n"
     "-------------------------------------------------------------------------------------"
     "\n[%@]                                     %@\n"
     "-------------------------------------------------------------------------------------"
     "\n\n%s\n"
     "\n%@\n",
     [dateFormatter stringFromDate:[NSDate date]],
     [NSThread isMainThread] ? @"" : [NSString stringWithFormat:@"[Background:%p]", [NSThread currentThread]],
     func,
     msg];
    
    // Redirect stderr to file
    if (logFile) {
        // Create log dir
        if (! [[NSFileManager defaultManager] fileExistsAtPath:logFile]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[logFile stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        // Redirect stderr
        const char *PATH = [logFile fileSystemRepresentation];
        freopen(PATH, "a", stderr);
    }
    
    // Prevent garbled logs due to logging on multiple threads
    static id synchronizer = nil;
    id localSynchronizerRef = synchronizer ?: (synchronizer = [NSDate date]);
    
    // Log
    @synchronized (localSynchronizerRef) {
        fprintf(stderr, "%s", [formattedMsg UTF8String]);
    }
    fflush(stderr);
}
#
#   ifndef LOG_FILE
#       define LOG_FILE nil
#   endif
#   define DLog(fmt, ...) DebugLog(LOG_FILE, self.class, __PRETTY_FUNCTION__, fmt, ##__VA_ARGS__)
#   define IsLogging YES
#
#else /* ! DEBUG */
#
#   define DLog(...)
#   define IsLogging NO
#
#endif /* DEBUG */

#endif /* PostgreSQL_Debug_h */

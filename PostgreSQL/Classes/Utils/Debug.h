//
//  Debug.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 19/7/15.
//  Copyright (c) 2011-2020 Macca Tech Ltd. (http://macca.tech)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#ifndef PostgreSQL_Debug_h
#define PostgreSQL_Debug_h

#ifdef DEBUG
#
static inline void DebugLog(NSString *logFile, const char *func, NSString* fmt, ...)
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
#   define DLog(fmt, ...) DebugLog(LOG_FILE, __PRETTY_FUNCTION__, fmt, ##__VA_ARGS__)
#   define IsLogging YES
#
#else /* ! DEBUG */
#
#   define DLog(...)
#   define IsLogging NO
#
#endif /* DEBUG */

#endif /* PostgreSQL_Debug_h */

//
//  Common.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 HK Web Entrepreneurs. All rights reserved.
//

#ifndef PostgreSQL_Common_h
#define PostgreSQL_Common_h

#ifdef DEBUG
#
#   define LOG_FILE [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/PostgreSQL/PostgreSQL.log"]
#
// DLog is almost a drop-in replacement for NSLog
// DLog();
// DLog(@"here");
// DLog(@"value: %d", x);
// Unfortunately this doesn't work DLog(aStringVariable); you have to do this instead DLog(@"%@", aStringVariable);
#   define DLog(fmt, ...) { if (! [[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE] ) { [[NSFileManager defaultManager] createDirectoryAtPath:[LOG_FILE stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL]; } const char *PATH = [LOG_FILE fileSystemRepresentation]; freopen(PATH, "a", stderr); NSLog((@"%s [Line %d] " fmt @"\n\n"), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }
#
#   define IsLogging YES
#
#else /* ! DEBUG */
#
#   define DLog(...)
#   define DLogInit(...)
#   define IsLogging NO
#
#endif /* DEBUG */

#endif /* PostgreSQL_Common_h */

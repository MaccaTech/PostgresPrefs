//
//  PGLaunchd.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 23/7/15.
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

#import <Foundation/Foundation.h>
#import "PGFile.h"
#import "PGProcess.h"
#import "PGRights.h"

#pragma mark - PGLaunchd
/**
 * Utility class for looking up and starting/stopping daemons in launchd
 */
@interface PGLaunchd : NSObject

/**
 * The rights required to start and stop launchd daemons.
 */
@property (class, nonatomic, readonly) PGRights *rights;

/**
 * Gets list of daemon names loaded in root user's or current user's launchd
 */
+ (NSArray *)loadedDaemonsWithNameLike:(NSString *)pattern forRootUser:(BOOL)root;

/**
 * Gets properties of daemons loaded in root users's or current user's launchd
 */
+ (NSDictionary *)loadedDaemonWithName:(NSString *)name forRootUser:(BOOL)root;

/**
 * Loads the daemon in launchd from the specified daemon property file.
 */
+ (BOOL)startDaemonWithFile:(NSString *)file forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error;

/**
 * Unloads the named daemon from launchd.
 *
 * Note: silently does nothing if daemon is not already loaded.
 */
+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error;

@end

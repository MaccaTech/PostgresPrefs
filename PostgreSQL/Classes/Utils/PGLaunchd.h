//
//  PGLaunchd.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 23/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
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
+ (PGRights *)rights;

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
+ (BOOL)startDaemonWithFile:(NSString *)file forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Unloads the named daemon from launchd.
 *
 * Note: silently does nothing if daemon is not already loaded.
 */
+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

@end

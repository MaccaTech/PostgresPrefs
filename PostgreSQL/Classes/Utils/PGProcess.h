//
//  PGShell.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 5/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Utility class for running executables or shell commands/scripts as subprocesses.
 */
@interface PGProcess : NSObject

/**
 * The rights required to run an authorized command.
 */
+ (AuthorizationRights *)authorizationRights;
/**
 * Runs command in shell without authorization. Returns output.
 */
+ (NSString*)runShellCommand:(NSString *)command withArgs:(NSArray *)command;
/**
 * Runs command in shell with authorization (if not NULL). Returns output.
 */
+ (NSString*)runShellCommand:(NSString *)command withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;
/**
 * Runs command in shell without authorization. Does not wait for output.
 */
+ (void)startShellCommand:(NSString *)command withArgs:(NSArray *)args;
/**
 * Runs command in shell with authorization (if not NULL). Does not wait for output.
 */
+ (void)startShellCommand:(NSString *)command withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;

/**
 * Runs executable without authorization, using specified args. Does not wait for output.
 */
+ (void)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args;
/**
 * Runs executable without authorization with specified args. Returns output.
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args;
/**
 * Runs executable with authorization (if not NULL) with specified args. Does not wait for output.
 */
+ (void)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;
/**
 * Runs executable with authorization (if not NULL) with specified args. Returns output.
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;

@end

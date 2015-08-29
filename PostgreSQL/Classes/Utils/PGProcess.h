//
//  PGShell.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 5/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGRights.h"

/**
 * Utility class for running executables or shell commands/scripts as subprocesses.
 *
 * Also looks up running processes.
 */
@interface PGProcess : NSObject

/// Process id of running process
@property (nonatomic) NSInteger pid;
/// Parent process id of running process
@property (nonatomic) NSInteger ppid;
/// Command of running process
@property (nonatomic, strong) NSString *command;

/**
 * Gets running process for specified pid.
 */
+ (PGProcess *)runningProcessWithPid:(NSInteger)pid;

/**
 * Gets all running processes matching the name pattern.
 */
+ (NSArray *)runningProcessesWithNameLike:(NSString *)pattern;

/**
 * Kill a process
 */
+ (BOOL)kill:(NSInteger)pid forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * The rights required to run an authorized command.
 */
+ (PGRights *)rights;

/**
 * Starts command in shell without authorization. Does not wait for output.
 *
 * @return YES if started without throwing an exception
 */
+ (BOOL)startShellCommand:(NSString *)command error:(NSString **)error;
/**
 * Runs command in shell without authorization. Returns output.
 *
 * @return output of running command, or nil if exception was thrown
 */
+ (NSString *)runShellCommand:(NSString *)command error:(NSString **)error;

/**
 * Starts command in shell with authorization (if not nil). Does not wait for output.
 *
 * @return YES if started without throwing an exception or authorization error
 */
+ (BOOL)startShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;
/**
 * Runs command in shell with authorization (if not nil). Any output is treated as an error.
 *
 * @return YES if ran without throwing an exception or authorization error and with no output
 */
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;
/**
 * Runs command in shell with authorization (if not nil). Returns output separately.
 *
 * @return YES if ran without throwing an exception or authorization error
 */
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString **)output error:(NSString **)error;

/**
 * Starts executable without authorization. Does not wait for output.
 *
 * @return YES if started without throwing an exception or authorization error
 */
+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString **)error;
/**
 * Runs executable without authorization. Returns output.
 *
 * @return output of running executable, or nil if exception was thrown
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString **)error;

/**
 * Starts executable with authorization (if not nil). Does not wait for output.
 *
 * @return YES if started without throwing an exception or authorization error
 */
+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;
/**
 * Runs executable with authorization (if not nil) with specified args. Returns output.
 *
 * @return YES if ran without throwing an exception or authorization error
 */
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString **)output error:(NSString **)error;

@end

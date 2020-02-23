//
//  PGProcess.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 5/7/15.
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
/// User of  running process
@property (nonatomic, strong) PGUser *user;
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
+ (BOOL)kill:(NSInteger)pid forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error;

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
+ (BOOL)startShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error;
/**
 * Runs command in shell with authorization (if not nil). Any output is treated as an error.
 *
 * @return YES if ran without throwing an exception or authorization error and with no output
 */
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error;
/**
 * Runs command in shell with authorization (if not nil). Returns output separately.
 *
 * @return YES if ran without throwing an exception or authorization error
 */
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth output:(NSString **)output error:(NSString **)error;

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
+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth error:(NSString **)error;
/**
 * Runs executable with authorization (if not nil) with specified args. Returns output.
 *
 * @return YES if ran without throwing an exception or authorization error
 */
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth output:(NSString **)output error:(NSString **)error;

@end

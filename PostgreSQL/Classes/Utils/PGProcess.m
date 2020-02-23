//
//  PGProcess.m
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

#import "PGProcess.h"

#pragma mark - Interfaces

@interface PGProcess ()

- (id)initWithPid:(NSInteger)pid ppid:(NSInteger)ppid user:(PGUser *)user command:(NSString *)command;

/**
 * @return the applescript file that makes it possible to run an executable with authorization
 */
+ (NSString *)authorizingScript;

/**
 * Catch-all method for running an unauthorized shell command, with or without capturing output.
 */
+ (BOOL)runShellCommand:(NSString *)command output:(NSString **)output error:(NSString **)error;

/**
 * Runs executable with or without authorization, with or without capturing output, and wrapped in a try/catch to capture any thrown exception.
 *
 * @param output If nil, does not wait for command to complete. Otherwise, captures output.
 * @return YES if succeeded without throwing an exception or authorization error
 */
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth output:(NSString **)output error:(NSString **)error;

/**
 * Runs executable without authorization and either returns output or returns immediately with no output
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args waitForOutput:(BOOL)waitForOutput;

/**
 * Runs executable with authorization and either returns output or returns immediately with no output
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth waitForOutput:(BOOL)waitForOutput;

@end



#pragma mark - PGProcess

@implementation PGProcess

#pragma mark Running Processes

- (id)initWithPid:(NSInteger)pid ppid:(NSInteger)ppid user:(PGUser *)user command:(NSString *)command
{
    self = [super init];
    if (self) {
        _pid = pid;
        _ppid = ppid;
        _user = user;
        _command = command;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ %@", @(_pid), @(_ppid), _command];
}

+ (PGProcess *)processFromPsCommandOutput:(NSString *)output
{
    if (!NonBlank(output)) return nil;
    
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\A\\s*(\\d+)\\s+(\\d+)\\s+(\\S+)\\s+(.*?)\\s*\\z" options:0 error:nil];
    });
    
    NSTextCheckingResult *match = [regex firstMatchInString:output options:0 range:NSMakeRange(0,output.length)];
    if (match.numberOfRanges != 5) return nil;
    
    NSString *pid = [output substringWithRange:[match rangeAtIndex:1]];
    NSString *ppid = [output substringWithRange:[match rangeAtIndex:2]];
    NSString *user = [output substringWithRange:[match rangeAtIndex:3]];
    NSString *command = [output substringWithRange:[match rangeAtIndex:4]];
    return [[PGProcess alloc] initWithPid:pid.integerValue ppid:ppid.integerValue user:[PGUser userWithUsername:user] command:command];
}
+ (PGProcess *)runningProcessWithPid:(NSInteger)pid
{
    NSString *command = [NSString stringWithFormat:@"ps -o pid=,ppid=,user=,command= -p %@", @(pid)];
    return [self processFromPsCommandOutput:[self runShellCommand:command error:nil]];
}
+ (NSArray *)runningProcessesWithNameLike:(NSString *)pattern
{
    NSString *command = [NSString stringWithFormat:@"ps -eao pid=,ppid=,user=,command= | grep -v grep | grep -i '%@'", pattern];
    NSArray *lines = [[self runShellCommand:command error:nil] componentsSeparatedByString:@"\n"];
    if (lines.count == 0) return nil;
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:lines.count];
    for (NSString *line in lines) {
        PGProcess *process = [self processFromPsCommandOutput:line];
        if (process) [result addObject:process];
    }
    return result.count == 0 ? nil : [NSArray arrayWithArray:result];
}

+ (BOOL)kill:(NSInteger)pid forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    if (pid <= 0) return NO;
    
    NSString *command = [NSString stringWithFormat:@"kill %@", @(pid)];
    return [self runShellCommand:command forRootUser:root auth:auth error:error];
}



#pragma mark Authorization

+ (NSString *)authorizingScript
{
    static NSString *script;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        script = [[NSBundle bundleForClass:[self class]] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
        if (!script) DLog(@"Cannot find resource PGPrefsRunAsAdmin.scpt!");
    });

    return script;
}
+ (PGRights *)rights
{
    static PGRights *rights;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rights = [PGRights rightsWithRightName:@kAuthorizationRightExecute value:self.authorizingScript];
    });
    return rights;
}



#pragma mark Shell Commands

+ (BOOL)startShellCommand:(NSString *)command error:(NSString *__autoreleasing *)error
{
    return [self runShellCommand:command output:nil error:error];
}
+ (NSString *)runShellCommand:(NSString *)command error:(NSString *__autoreleasing *)error
{
    NSString *result = nil;
    [self runShellCommand:command output:&result error:error];
    return result;
}
+ (BOOL)runShellCommand:(NSString *)command output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)error
{
    command = TrimToNil(command);
    if (!command) return NO;
    
    return [self runExecutable:@"/bin/bash" withArgs:@[@"-c", command] auth:nil output:output error:error];
}
+ (BOOL)startShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self runShellCommand:command forRootUser:root auth:auth output:nil error:error];
}
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    NSString *output = nil;
    if (![self runShellCommand:command forRootUser:root auth:auth output:&output error:error]) return NO;
    if (error) *error = output;
    return !output;
}
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root auth:(PGAuth *)auth output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)outerr
{
    command = TrimToNil(command);
    if (!command) return NO;
    
    // Run unauthorized
    if (!root) {
        return [self runShellCommand:command output:output error:outerr];
    }
    
    // Authorization required
    AuthorizationRef authorization = [auth authorize:self.rights];

    if (!authorization) {
        if (outerr) { *outerr = [NSString stringWithFormat:@"Authorization required to run command: %@", command]; }
        return NO;
    }

    // Program error - authorization script missing!
    NSString *authorizingScript = [self authorizingScript];
    if (!authorizingScript) {
        [auth invalidate:errAuthorizationInternal];
        return NO;
    }
    
    // Script always runs as root, so need to switch user, and force bash shell.
    if (!root) {
        command = [NSString stringWithFormat:@"sudo -u \"%@\" -s \"/bin/bash\" -c '%@'", NSUserName(), command];
        
    // Force bash shell
    } else {
        command = [NSString stringWithFormat:@"#!/bin/bash\n%@", command];
    }
    
    // Execute
    return [self runExecutable:@"/usr/bin/osascript" withArgs:@[authorizingScript, command] auth:auth output:output error:outerr];
}



#pragma mark Executables

+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString *__autoreleasing *)error
{
    return [self runExecutable:pathToExecutable withArgs:args auth:nil output:nil error:error];
}
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString *__autoreleasing *)error
{
    NSString *result = nil;
    [self runExecutable:pathToExecutable withArgs:args auth:nil output:&result error:error];
    return result;
}
+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self runExecutable:pathToExecutable withArgs:args auth:auth output:nil error:error];
}
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)error
{
    BOOL ignoreOutput = !output;
    BOOL unauthorized = !auth;
    
    NSString *resultOutput = nil;
    NSString *resultError = nil;
    
    @try {
        
        // Unauthorized
        if (unauthorized) {
            resultOutput = [self runExecutable:pathToExecutable withArgs:args waitForOutput:!ignoreOutput];
            return YES;
        
        // Authorized
        } else {
            resultOutput = [self runExecutable:pathToExecutable withArgs:args auth:auth waitForOutput:!ignoreOutput];
            return auth.status == errAuthorizationSuccess;
        }
            
    } @catch (NSException *err) {
        resultError = [NSString stringWithFormat:@"%@\n%@", [err name], [err reason]];
        
        return NO;
        
    } @finally {
        if (output) { *output = resultOutput; }
        if (error) { *error = resultError; }
    }
}



#pragma mark Private

+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args waitForOutput:(BOOL)waitForOutput
{
    if (IsLogging) DLog(@"%@", [[@[pathToExecutable] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = pathToExecutable;
    if (args) task.arguments = args;
    
    NSPipe *pipeStdout = [NSPipe pipe];
    NSPipe *pipeStderr = [NSPipe pipe];
    task.standardOutput = pipeStdout;
    task.standardError = pipeStderr;
    task.standardInput = [NSPipe pipe];
    
    NSFileHandle *fileStdout = [pipeStdout fileHandleForReading];
    NSFileHandle *fileStderr = [pipeStderr fileHandleForReading];
    
    // Run
    [task launch];
    
    // Return immediately if output not required
    if (!waitForOutput) return nil;
    
    // Wait for task to finish and return output from stdout or stderr
    [task waitUntilExit];
    NSFileHandle *file = task.terminationStatus != 0 ? fileStderr : fileStdout;
    NSData *data = [file readDataToEndOfFile];
    NSString *result = TrimToNil([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return result;
}

+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args auth:(PGAuth *)auth waitForOutput:(BOOL)waitForOutput
{
    // Log
    if (IsLogging) DLog(@"Running Authorized: %@", [self descriptionForExecutable:pathToExecutable withArgs:args]);

    // Authorize
    AuthorizationRef authorization = [auth authorize:self.rights];
    if (!authorization) {
        DLog(@"Cannot run without authorization!");
        return [NSString stringWithFormat:@"Cannot run command without auth: %@", [self descriptionForExecutable:pathToExecutable withArgs:args]];
    }
    
    // Convert command into const char*;
    const char *commandArg = strdup([pathToExecutable UTF8String]);
    
    // Convert args array into void-* array.
    const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
    int argvIndex = 0;
    for (NSString *string in args) {
        // If we just using the returned UTF8String, strange things happen
        argv[argvIndex] = strdup([string UTF8String]);
        argvIndex++;
    }
    argv[argvIndex] = nil;
    
    // Pipe for collecting output
    FILE *processOutput = NULL;
    
    // Run command with authorization
    FILE **processOutputRef = waitForOutput ? &processOutput : NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(authorization, commandArg, kAuthorizationFlagDefaults, (char *const *)argv, processOutputRef);
#pragma clang diagnostic pop
    if (status != errAuthorizationSuccess) { [auth invalidate:status]; }
    
    // Release command and args
    free((char*)commandArg);
    for (int i = 0; i < argvIndex; i++) free((char*)argv[i]);
    free(argv);
    
    // Get output
    NSString *result = nil;
    
    // Only return output if no errors
    if (status == errAuthorizationSuccess && waitForOutput) {
        
        // Read the output from the FILE pipe up to EOF (or other error).
#define READ_BUFFER_SIZE 64
        char readBuffer[READ_BUFFER_SIZE];
        NSMutableString *stdoutString = [NSMutableString string];
        size_t charsRead;
        while ((charsRead = fread(readBuffer, 1, READ_BUFFER_SIZE, *processOutputRef)) != 0) {
            NSString *bufferString = [[NSString alloc] initWithBytes:readBuffer length:charsRead encoding:NSUTF8StringEncoding];
            [stdoutString appendString:bufferString];
        }
        
        // Trim output
        result = TrimToNil(stdoutString);
    }
    
    // Close pipe
    fclose(processOutput);
    
    // Log
    if (IsLogging) {
        if (status != errAuthorizationSuccess) {
            DLog(@"Error: %d", status);
        } else if (waitForOutput) {
            if (result) {
                DLog(@"Result: %@", result);
            } else {
                DLog(@"No result");
            }
        } else {
            DLog(@"Done");
        }
    }
    
    return result;
}

+ (NSString *)descriptionForExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args
{
    return [[@[pathToExecutable] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "];
}

@end

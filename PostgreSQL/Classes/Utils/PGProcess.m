//
//  PGShell.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 5/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGProcess.h"

#pragma mark - Interfaces

@interface PGProcess ()

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
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString **)output error:(NSString **)error;

/**
 * Runs executable without authorization and either returns output or returns immediately with no output
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args waitForOutput:(BOOL)waitForOutput;

/**
 * Runs executable with authorization and either returns output or returns immediately with no output
 */
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus waitForOutput:(BOOL)waitForOutput;

@end



#pragma mark - PGShell

@implementation PGProcess

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
+ (AuthorizationRights *)authorizationRights
{
    static NSString *authorizingScript;
    static AuthorizationItem authorizationItem;
    static AuthorizationRights authorizationRights;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        authorizingScript = [self authorizingScript];
        if (authorizingScript) {
            AuthorizationItem item = {kAuthorizationRightExecute, authorizingScript.length, &authorizingScript, 0};
            AuthorizationRights rights = {1, &authorizationItem};
            authorizationItem = item;
            authorizationRights = rights;
        }
    });

    return authorizationRights.count == 0 ? nil : &authorizationRights;
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
    
    return [self runExecutable:@"/bin/bash" withArgs:@[@"-c", command] authorization:nil authStatus:nil output:output error:error];
}
+ (BOOL)startShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    return [self runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:nil error:error];
}
+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)error
{
    command = TrimToNil(command);
    if (!command) return NO;
    
    // No authorization provided - run unauthorized or abort
    if (!authorization) {
        if (root) return NO;
        else return [self runShellCommand:command output:output error:error];
    }
    
    // Program error - authorization script missing!
    NSString *authorizingScript = [self authorizingScript];
    if (!authorizingScript) {
        if (authStatus) *authStatus = errAuthorizationInternal;
        return NO;
    }
    
    // Script always runs as root, so need to switch user
    if (!root) command = [NSString stringWithFormat:@"su \"%@\" -c '%@'", NSUserName(), command];
    
    // Execute
    return [self runExecutable:@"/usr/bin/osascript" withArgs:@[authorizingScript, command] authorization:authorization authStatus:authStatus output:output error:error];
}



#pragma mark Executabless

+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString *__autoreleasing *)error
{
    return [self runExecutable:pathToExecutable withArgs:args authorization:nil authStatus:nil output:nil error:error];
}
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args error:(NSString *__autoreleasing *)error
{
    NSString *result = nil;
    [self runExecutable:pathToExecutable withArgs:args authorization:nil authStatus:nil output:&result error:error];
    return result;
}
+ (BOOL)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    return [self runExecutable:pathToExecutable withArgs:args authorization:authorization authStatus:authStatus output:nil error:error];
}
+ (BOOL)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)error
{
    BOOL ignoreOutput = !output;
    BOOL unauthorized = !authorization;
    
    NSString *resultOutput = nil;
    NSString *resultError = nil;
    OSStatus resultAuthStatus = errAuthorizationSuccess;
    
    @try {
        
        // Unauthorized
        if (unauthorized) {
            resultOutput = [self runExecutable:pathToExecutable withArgs:args waitForOutput:!ignoreOutput];
        
        // Authorized
        } else {
            resultOutput = [self runExecutable:pathToExecutable withArgs:args authorization:authorization authStatus:&resultAuthStatus waitForOutput:!ignoreOutput];
            
            // Pass on auth status
            if (authorization) {
                if (authStatus) *authStatus = resultAuthStatus;
                
                // User cancelled auth
                if (resultAuthStatus != errAuthorizationSuccess) return NO;
            }
        }
        
        // Pass on output
        if (output) *output = resultOutput;
        
        return YES;
    }
    @catch (NSException *err) {
        resultError = [NSString stringWithFormat:@"%@\n%@", [err name], [err reason]];
        
        // Pass on error
        if (error) *error = resultError;
        
        return NO;
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

+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus waitForOutput:(BOOL)waitForOutput
{
    // Pre-check the authorization - it may have timed-out
    OSStatus status = !authorization ? errAuthorizationInvalidRef : AuthorizationCopyRights(authorization, self.authorizationRights, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, NULL);
    if (authStatus) *authStatus = status;
    if (status != errAuthorizationSuccess) return nil;
    
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
    
    // Log
    if (IsLogging) DLog(@"Running Authorized: %@", [[@[pathToExecutable] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);
    
    // Run command with authorization
    FILE **processOutputRef = waitForOutput ? &processOutput : NULL;
    status = AuthorizationExecuteWithPrivileges(authorization, commandArg, kAuthorizationFlagDefaults, (char *const *)argv, processOutputRef);
    if (authStatus) *authStatus = status;
    
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
    if (status != errAuthorizationSuccess) {
        DLog(@"Error: %d", status);
    } else if (waitForOutput) {
        DLog(@"Result: %@", result);
    } else {
        DLog(@"Done");
    }
    
    return result;
}

@end

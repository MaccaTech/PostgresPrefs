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
    static BOOL initialized;
    
    // Find script in bundle
    if (!initialized) {
        script = [[NSBundle bundleForClass:[self class]] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
        if (!script) DLog(@"Cannot find resource PGPrefsRunAsAdmin.scpt!");
        initialized = YES;
    }

    return script;
}
+ (AuthorizationRights *)authorizationRights
{
    static NSString *authorizingScript;
    static AuthorizationItem authorizationItem;
    static AuthorizationRights authorizationRights;
    static BOOL initialized;
    
    // Create rights
    if (!initialized) {
        authorizingScript = [self authorizingScript];
        if (authorizingScript) {
            AuthorizationItem item = {kAuthorizationRightExecute, authorizingScript.length, &authorizingScript, 0};
            AuthorizationRights rights = {1, &authorizationItem};
            authorizationItem = item;
            authorizationRights = rights;
        }
        initialized = YES;
    }

    return authorizationRights.count == 0 ? nil : &authorizationRights;
}



#pragma mark Shell Commands

+ (NSString*)runShellCommand:(NSString *)command withArgs:(NSArray *)args
{
    return [self runShellCommand:command withArgs:args authorization:nil authStatus:NULL];
}
+ (NSString*)runShellCommand:(NSString *)command withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    if (authorization == NULL) {
        return [self runExecutable:@"/bin/bash" withArgs:[@[@"-c", command] arrayByAddingObjectsFromArray:args]];
    }
    
    // Program error - authorization script missing!
    NSString *authorizingScript = [self authorizingScript];
    if (!authorizingScript) {
        if (authStatus != NULL) *authStatus = errAuthorizationInternal;
        return nil;
    }
    
    // Execute
    return [self runExecutable:@"/usr/bin/osascript" withArgs:[@[authorizingScript, command] arrayByAddingObjectsFromArray:args] authorization:authorization authStatus:authStatus];
}
+ (void)startShellCommand:(NSString *)command withArgs:(NSArray *)args
{
    [self startShellCommand:command withArgs:args authorization:nil authStatus:NULL];
}
+ (void)startShellCommand:(NSString *)command withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    if (authorization == NULL) {
        [self startExecutable:@"/bin/bash" withArgs:[@[@"-c", command] arrayByAddingObjectsFromArray:args]];
        return;
    }
    
    // Program error - authorization script missing!
    NSString *authorizingScript = [self authorizingScript];
    if (!authorizingScript) {
        if (authStatus != NULL) *authStatus = errAuthorizationInternal;
        return;
    }

    // Execute
    [self startExecutable:@"/usr/bin/osascript" withArgs:[@[authorizingScript, command] arrayByAddingObjectsFromArray:args] authorization:authorization authStatus:authStatus];
}



#pragma mark Executabless

+ (void)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args
{
    [self runExecutable:pathToExecutable withArgs:args waitForOutput:NO];
}
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args
{
    return [self runExecutable:pathToExecutable withArgs:args waitForOutput:YES];
}
+ (void)startExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    if (authorization == NULL) {
        [self startExecutable:pathToExecutable withArgs:args];
        return;
    }
    
    [self runExecutable:pathToExecutable withArgs:args authorization:authorization authStatus:authStatus waitForOutput:NO];
}
+ (NSString *)runExecutable:(NSString *)pathToExecutable withArgs:(NSArray *)args authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    if (authorization == NULL) {
        return [self runExecutable:pathToExecutable withArgs:args];
    }
    
    return [self runExecutable:pathToExecutable withArgs:args authorization:authorization authStatus:authStatus waitForOutput:YES];
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
    OSStatus status = authorization == NULL ? errAuthorizationInvalidRef :AuthorizationCopyRights(authorization, self.authorizationRights, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, NULL);
    if (authStatus != NULL) *authStatus = status;
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
    if (authStatus != NULL) *authStatus = status;
    
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

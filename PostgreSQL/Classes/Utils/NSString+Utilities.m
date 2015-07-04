//
//  NSString+Utilities.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 HK Web Entrepreneurs. All rights reserved.
//

#import "NSString+Utilities.h"

#pragma mark - NSString (Private)

@interface NSString (Private)
/**
 * Runs a command with no authorization and either returns output or returns immediately with no output
 */
- (NSString *)runWithArgs:(NSArray *)args waitForOutput:(BOOL)waitForOutput;
/**
 * Runs a shell command with authorization and either returns output or returns immediately with no output
 */
- (NSString *)runWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization  waitForOutput:(BOOL)waitForOutput;
@end

@implementation NSString (Private)

- (NSString *)runWithArgs:(NSArray *)args waitForOutput:(BOOL)waitForOutput
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self];
    if (args) {
        [task setArguments:args];
    }
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    //The magic line that keeps your log where it belongs
    [task setStandardInput:[NSPipe pipe]];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    // Log
    if (IsLogging) DLog(@"Running: %@", [[@[self] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);
    
    // Run
    [task launch];
    
    if (waitForOutput) {
        [task waitUntilExit];
    }
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSString *result = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([result length] == 0) {
        result = nil;
    }
    return result;
}
- (NSString *)runWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization waitForOutput:(BOOL)waitForOutput
{
    // Convert command into const char*;
    const char *commandArg = strdup([self UTF8String]);
    
    // Convert args array into void-* array.
    const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
    int argvIndex = 0;
    if (args) {
        for (NSString *string in args) {
            // If we just using the returned UTF8String, strange things happen
            argv[argvIndex] = strdup([string UTF8String]);
            argvIndex++;
        }
    }
    argv[argvIndex] = nil;
    
    // Pipe for collecting output
    FILE *processOutput;
    processOutput = NULL;
    
    // Log
    if (IsLogging) DLog(@"Running Authorized: %@", [[@[self] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);
    
    // Run command with authorization
    FILE **processOutputRef = waitForOutput ? &processOutput : NULL;
    OSStatus processError = AuthorizationExecuteWithPrivileges(authorization, commandArg, kAuthorizationFlagDefaults, (char *const *)argv, processOutputRef);
    
    // Release command and args
    free((char*)commandArg);
    if (args) {
        for (int i = 0; i < argvIndex; i++) {
            free((char*)argv[i]);
        }
    }
    free(argv);
    
    // Get output
    NSString *result = nil;
    
    // Check for errors
    if (processError != errAuthorizationSuccess) {
        DLog(@"Error: %d", processError);
        
        // Only return output if no errors
    } else if (waitForOutput) {
        
        // Read the output from the FILE pipe up to EOF (or other error).
#define READ_BUFFER_SIZE 64
        char readBuffer[READ_BUFFER_SIZE];
        NSMutableString *processOutputString = [NSMutableString string];
        size_t charsRead;
        while ((charsRead = fread(readBuffer, 1, READ_BUFFER_SIZE, *processOutputRef)) != 0) {
            NSString *bufferString =
            [[NSString alloc]
             initWithBytes:readBuffer
             length:charsRead
             encoding:NSUTF8StringEncoding];
            [processOutputString appendString:bufferString];
        }
        
        // Trim output
        result = [processOutputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([result length] == 0) {
            result = nil;
        }
    }
    
    // Close pipe
    fclose(processOutput);
    
    // Log
    if (waitForOutput) {
        DLog(@"Result: %@", result);
    } else {
        DLog(@"Done");
    }
    
    return result;
}

@end



#pragma mark - NSString (Utilities)

@implementation NSString (Utilities)

- (BOOL)nonBlank
{
    static NSCharacterSet *nonBlanks;
    if (!nonBlanks) nonBlanks = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return [self rangeOfCharacterFromSet:nonBlanks].location != NSNotFound;
}
- (NSString *)trimToNil
{
    NSString *trimmed = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [trimmed length] > 0 ? trimmed : nil;
}

- (void)startWithArgs:(NSArray *)args
{
    [self runWithArgs:args waitForOutput:NO];
}
- (NSString *)runWithArgs:(NSArray *)args
{
    return [self runWithArgs:args waitForOutput:YES];
}
- (void)startWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization
{
    [self runWithArgs:args authorization:authorization waitForOutput:NO];
}
- (NSString *)runWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization
{
    return [self runWithArgs:args authorization:authorization waitForOutput:YES];
}

@end

/*

//
// Utility method - check if NSString is blank
//
BOOL isBlankString(id string) {
    if (string && string != [NSNull null]) {
        if ([string isKindOfClass:[NSString class]]) {
            return [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;
        } else {
            return NO;
        }
    }
    return YES;
}

//
// Utility method - check if NSString is non-blank
//
BOOL isNonBlankString(id value) {
    return (value && value != [NSNull null] && [value isKindOfClass:[NSString class]] && [value length] > 0);
}

*/
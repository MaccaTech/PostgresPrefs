//
//  PGLaunchd.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 23/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGLaunchd.h"

#pragma mark - Interfaces

/**
 * Utility class for holding a regex search/replace definition, for applying it to a string and storing any error.
 */
@interface PGReplace : NSObject

@property (nonatomic, strong, readonly) NSRegularExpression *regex;
@property (nonatomic, strong, readonly) NSString *replacement;
@property (nonatomic, strong, readonly) NSError *error;
- (id)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options replacement:(NSString *)replacement;
+ (PGReplace *)pattern:(NSString *)pattern replacement:(NSString *)replacement;
+ (PGReplace *)pattern:(NSString *)pattern replacement:(NSString *)replacement options:(NSRegularExpressionOptions)options;
/**
 * The main method - applies the regex search/replace to the string.
 */
- (void)apply:(NSMutableString *)string;
@end



@interface PGLaunchd()

/**
 * Converts the output of running `launchctl list <name>` to a dictionary of properties.
 */
+ (NSDictionary *)parseListAgentOutput:(NSString *)output error:(NSString **)error;

@end



#pragma mark - PGReplace

@implementation PGReplace

- (id)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options replacement:(NSString *)replacement
{
    self = [super init];
    if (self) {
        NSError *error;
        _regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
        _replacement = replacement;
        _error = error;
    }
    return self;
}
- (void)apply:(NSMutableString *)string
{
    [self.regex replaceMatchesInString:string options:0 range:NSMakeRange(0,string.length) withTemplate:_replacement];
}
+ (PGReplace *)pattern:(NSString *)pattern replacement:(NSString *)replacement
{
    return [PGReplace pattern:pattern replacement:replacement options:0];
}
+ (PGReplace *)pattern:(NSString *)pattern replacement:(NSString *)replacement options:(NSRegularExpressionOptions)options
{
    return [[PGReplace alloc] initWithPattern:pattern options:options replacement:replacement];
}

@end



#pragma mark - PGLaunchd

@implementation PGLaunchd

#pragma mark Main Methods

+ (NSArray *)loadedDaemonsWithNameLike:(NSString *)pattern forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    pattern = TrimToNil(pattern);
    
    NSString *command = NonBlank(pattern) ? [NSString stringWithFormat:@"launchctl list | cut -f3 | grep -e \"%@\"", pattern] : @"launchctl list";
    NSString *output = nil;
    BOOL succeeded = [self runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return nil;
    
    return [output componentsSeparatedByString:@"\n"];
}

+ (NSDictionary *)loadedDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    name = TrimToNil(name);
    if (!NonBlank(name)) return nil;
    
    NSString *command = [NSString stringWithFormat:@"launchctl list \"%@\"", name];
    NSString *output = nil;
    BOOL succeeded = [self runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return nil;
    
    return [self parseListAgentOutput:output error:error];
}

+ (BOOL)startDaemonWithFile:(NSString *)file forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    file = TrimToNil(file);
    if (!NonBlank(file)) return NO;
    
    file = [file stringByExpandingTildeInPath];
    
    // Invalid file
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory] || isDirectory) {
        if (error) *error = [NSString stringWithFormat:@"Not a valid daemon property file: %@", file];
        return NO;
    }
    
    NSString *command = [NSString stringWithFormat:@"launchctl load -F \"%@\"", file];
    NSString *output = nil;
    BOOL succeeded = [self runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return NO;
    
    return YES;
}

+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    name = TrimToNil(name);
    if (!NonBlank(name)) return NO;
    
    NSString *command = [NSString stringWithFormat:@"launchctl remove \"%@\"", name];
    NSString *output = nil;
    BOOL succeeded = [self runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return NO;
    
    return YES;
}



#pragma mark Private

+ (BOOL)runShellCommand:(NSString *)command forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus output:(NSString *__autoreleasing *)output error:(NSString *__autoreleasing *)error
{
    if (root && !authorization) return NO;
    if (!NonBlank(command)) return NO;
    
    // Will run as root, but want user-specific launchd, so command must switch user
    if (!root && authorization)
        command = [NSString stringWithFormat:@"su \"%@\" -c '%@'", NSUserName(), command];
    
    // Run
    return [PGProcess runShellCommand:command authorization:authorization authStatus:authStatus output:output error:error];
}

+ (NSDictionary *)parseListAgentOutput:(NSString *)output error:(NSString **)error
{
    // Empty output
    if (!NonBlank(output)) {
        if (error) *error = @"Unrecognized response from launchctl";
        return nil;
    }
    
    // Not loaded
    if ([output rangeOfString:@"unknown response"].location != NSNotFound ||
        [output rangeOfString:@"Could not find service"].location != NSNotFound) {
        return nil;
    }
    
    // Output is not in plist format
    if (![output hasPrefix:@"{"]) {
        if (error) *error = @"Unrecognized response from launchctl";
        return nil;
    }
    
    // For converting plist output format to JSON
    static NSArray *replaces;
    if (!replaces) {
        replaces = @[
            // Array () --> Array []
            [PGReplace pattern:@" = \\((.*?)\\)(;\\s*(\\n|\\z))" replacement:@" = [$1]$2" options:NSRegularExpressionDotMatchesLineSeparators],

            // "PID" = 29897 --> "PID": 29897
            [PGReplace pattern:@" = " replacement:@": "],

            //     "PID" = 29897;
            // }
            // -->
            //     "PID" = 29897
            // }
            [PGReplace pattern:@";(\\s*[\\)\\}]|\\z)" replacement:@"$1"],

            // "PID" = 29897; --> "PID" = 29897,
            [PGReplace pattern:@";(\\s*\\n)" replacement:@",$1"]
        ];
    }
    
    // Convert launchctl list output to JSON format
    NSMutableString *outputAsJSON = [NSMutableString stringWithString:output];
    for (PGReplace *replace in replaces) [replace apply:outputAsJSON];
    
    // Convert JSON to dictionary
    NSString *jsonError = nil;
    NSDictionary *result = JsonToDictionary(outputAsJSON, &jsonError);
    if (error) *error = jsonError;
    if (jsonError) DLog(@"%@\n\n%@", outputAsJSON, jsonError);
    return result;
}

@end

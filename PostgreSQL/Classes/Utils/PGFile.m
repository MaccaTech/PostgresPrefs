//
//  PGFile.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 26/08/2015.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGFile.h"

@implementation PGFile

+ (BOOL)fileExists:(NSString *)file authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    file = [file stringByExpandingTildeInPath];
    
    NSString *command = [NSString stringWithFormat:@"[ -f \"%@\" ] || echo \"File not found: %@\"", file, file];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)dirExists:(NSString *)dir authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    dir = [dir stringByExpandingTildeInPath];
    
    NSString *command = [NSString stringWithFormat:@"[ -d \"%@\" ] || echo \"Directory not found: %@\"", dir, dir];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)createFile:(NSString *)file contents:(NSString *)contents owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    // Parent dir must exist
    if (![self createDir:[file stringByDeletingLastPathComponent] owner:owner authorization:authorization authStatus:authStatus error:error]) return NO;

    file = [file stringByExpandingTildeInPath];
    if (!owner) owner = NSUserName();
    
    // Execute command
    NSString *command = [NSString stringWithFormat:@"echo \"%@\" > \"%@\" && chown %@ \"%@\"", contents?:@"", file, owner, file];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)createPlistFile:(NSString *)file contents:(NSDictionary *)contents owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    // Parent dir must exist
    if (![self createDir:[file stringByDeletingLastPathComponent] owner:owner authorization:authorization authStatus:authStatus error:error]) return NO;
    
    file = [file stringByExpandingTildeInPath];
    if (!owner) owner = NSUserName();

    // Write output to temporary file
    NSString *globallyUniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:globallyUniqueString];
    NSOutputStream *tempStream = [NSOutputStream outputStreamToFileAtPath:tempFile append:NO];
    [tempStream open];
    NSError *writeError = nil;
    if ([NSPropertyListSerialization writePropertyList:contents toStream:tempStream format:NSPropertyListXMLFormat_v1_0 options:0 error:&writeError] == 0)
    {
        if (error) *error = [NSString stringWithFormat:@"Error creating property file: %@", writeError ?: [NSString stringWithFormat:@"invalid data or permissions for dir %@", [file stringByDeletingLastPathComponent]]];
        return NO;
    }
    
    // Move temporary file to final location
    NSString *command = [NSString stringWithFormat:@"mv \"%@\" \"%@\" && chown %@ \"%@\"", tempFile, file, owner, file];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)deleteFile:(NSString *)file authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    // Already deleted
    if (!FileExists(file)) return YES;
    
    // Execute command
    NSString *command = [NSString stringWithFormat:@"rm \"%@\"", [file stringByExpandingTildeInPath]];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)createDir:(NSString *)dir owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    // Already exists
    if (DirExists(dir)) return YES;
    
    dir = [dir stringByExpandingTildeInPath];
    if (!owner) owner = NSUserName();
    
    // Execute command
    NSString *command = [NSString stringWithFormat:@"mkdir -p \"%@\" && chown %@ \"%@\"", dir, owner, dir];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

@end

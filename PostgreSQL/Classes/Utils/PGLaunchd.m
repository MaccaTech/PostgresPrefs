//
//  PGLaunchd.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 23/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGLaunchd.h"
#import <ServiceManagement/ServiceManagement.h>

#pragma mark - PGLaunchd

@implementation PGLaunchd

#pragma mark Main Methods

+ (NSArray *)loadedDaemonsWithNameLike:(NSString *)pattern forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    pattern = TrimToNil(pattern);
    
    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
    NSArray *allJobs = CFBridgingRelease(SMCopyAllJobDictionaries(domain));
    if (allJobs.count == 0) return nil;
    
    return pattern ? [allJobs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Label LIKE[cd] %@", pattern]] : allJobs;
}

+ (NSDictionary *)loadedDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    name = TrimToNil(name);
    if (!NonBlank(name)) return nil;
    
    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
    return CFBridgingRelease(SMJobCopyDictionary(domain, (__bridge CFStringRef)(name)));
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
    BOOL succeeded = [PGProcess runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return NO;
    
    return YES;
}

+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    name = TrimToNil(name);
    if (!NonBlank(name)) return NO;
    
    NSString *command = [NSString stringWithFormat:@"launchctl remove \"%@\"", name];
    NSString *output = nil;
    BOOL succeeded = [PGProcess runShellCommand:command forRootUser:root authorization:authorization authStatus:authStatus output:&output error:error];
    if (!succeeded) return NO;
    
    return YES;
}

@end

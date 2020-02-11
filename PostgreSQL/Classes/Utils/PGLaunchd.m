//
//  PGLaunchd.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 23/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGLaunchd.h"
#import <ServiceManagement/ServiceManagement.h>
#import <SystemConfiguration/SystemConfiguration.h>

#pragma mark - PGLaunchd

@implementation PGLaunchd

#pragma mark Main Methods

+ (PGRights *)rights
{
    static PGRights *rights;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // I wanted to add the kSMRightModifySystemDaemons to the list of rights,
        // so that I could use SMJobRemove to stop daemons (including system daemons),
        // instead of calling shell command 'launchctl remove'.
        // This worked, but it had the side-effect that the authorization would timeout
        // after 25 seconds, instead of 5 minutes.
        // So in the end, I abandoned using kSMRightModifySystemDaemons. However, a
        // solution to the timeout problem may present itself in future.
        // In which case, calling SMJobRemove would be preferable to calling a shell command.
        
//        PGRights *smRights = [PGRights rightsWithRightName:@kSMRightModifySystemDaemons value:nil];
//        rights = [PGRights rightsWithArrayOfRights:@[smRights, PGProcess.rights]];
        rights = PGProcess.rights;
    });
    
    return rights;
}

+ (NSArray *)loadedDaemonsWithNameLike:(NSString *)pattern forRootUser:(BOOL)root
{
    pattern = TrimToNil(pattern);
    
    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
    NSArray *allJobs = CFBridgingRelease(SMCopyAllJobDictionaries(domain));
    if (allJobs.count == 0) return nil;
    
    return pattern ? [allJobs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Label LIKE[cd] %@", pattern]] : allJobs;
}

+ (NSDictionary *)loadedDaemonWithName:(NSString *)name forRootUser:(BOOL)root
{
    name = TrimToNil(name);
    if (!name) return nil;
    
    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
    return CFBridgingRelease(SMJobCopyDictionary(domain, (__bridge CFStringRef)(name)));
}

+ (BOOL)startDaemonWithFile:(NSString *)file forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    file = TrimToNil(file);
    if (!file) return NO;
    
    file = [file stringByExpandingTildeInPath];
    
    // Invalid file
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory] || isDirectory) {
        if (error) *error = [NSString stringWithFormat:@"Not a valid daemon property file: %@", file];
        return NO;
    }
    
    // Get User Id
    uid_t uid = 0;
    SCDynamicStoreCopyConsoleUser(NULL, &uid, NULL);

    // Execute
    NSString *command = [NSString stringWithFormat:@"launchctl bootstrap gui/%@ \"%@\" && sleep 1", @(uid), file];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}

+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    name = TrimToNil(name);
    if (!name) return NO;
    
    // Silently ignore if daemon not loaded
    if (![self loadedDaemonWithName:name forRootUser:root]) return YES;
    
    // Get User Id
    uid_t uid = 0;
    SCDynamicStoreCopyConsoleUser(NULL, &uid, NULL);

    // Execute
    NSString *command = [NSString stringWithFormat:@"launchctl bootout \"gui/%@/%@\" && sleep 1", @(uid), name];
    return [PGProcess runShellCommand:command forRootUser:YES authorization:authorization authStatus:authStatus error:error];

//
//    See comment above - I am abandoning using SMJobRemove, as it leads to the
//    authorization timeout being severly reduced.
//
//    Hence below code is commented-out for the time being.
//
    
//    // Pre-check the authorization - it may have timed-out
//    if (root) {
//        if (![self.rights authorized:authorization authStatus:authStatus]) return NO;
//    }
//    
//    // Execute
//    CFErrorRef localError = nil;
//    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
//    BOOL succeeded = SMJobRemove(domain, (__bridge CFStringRef)name, authorization, YES, &localError);
//    
//    // Handle error
//    if (localError) {
//        if (error) *error = CFBridgingRelease(CFErrorCopyDescription(localError));
//        CFRelease(localError);
//    }
//    
//    return succeeded;
}

@end

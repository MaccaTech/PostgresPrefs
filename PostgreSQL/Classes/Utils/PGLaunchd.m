//
//  PGLaunchd.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 23/7/15.
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

#import "PGLaunchd.h"
#import <ServiceManagement/ServiceManagement.h>

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
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *allJobs = CFBridgingRelease(SMCopyAllJobDictionaries(domain));
    #pragma clang diagnostic pop
    if (allJobs.count == 0) return nil;
    
    return pattern ? [allJobs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Label LIKE[cd] %@", pattern]] : allJobs;
}

+ (NSDictionary *)loadedDaemonWithName:(NSString *)name forRootUser:(BOOL)root
{
    name = TrimToNil(name);
    if (!name) return nil;
    
    CFStringRef domain = root ? kSMDomainSystemLaunchd : kSMDomainUserLaunchd;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return CFBridgingRelease(SMJobCopyDictionary(domain, (__bridge CFStringRef)(name)));
    #pragma clang diagnostic pop
}

+ (BOOL)startDaemonWithFile:(NSString *)file forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error
{
    file = TrimToNil(file);
    if (!file) return NO;
    
    file = [file stringByExpandingTildeInPath];
    
    // Invalid file
    if (![PGFile fileExists:file]) {
        if (error) *error = [NSString stringWithFormat:@"Not a valid daemon property file: %@", file];
        return NO;
    }
    
    // Get Domain
    NSString *domain = root ? @"system" : [NSString stringWithFormat:@"gui/%@", @(PGUser.current.uid)];

    // Execute
    NSString *command = [NSString stringWithFormat:@"launchctl bootstrap %@ \"%@\"", domain, file];
    return [PGProcess runShellCommand:command forRootUser:root auth:auth error:error];
}

+ (BOOL)stopDaemonWithName:(NSString *)name forRootUser:(BOOL)root auth:(PGAuth *)auth error:(NSString **)error
{
    name = TrimToNil(name);
    if (!name) return NO;
    
    // Silently ignore if daemon not loaded
    if (![self loadedDaemonWithName:name forRootUser:root]) return YES;
    
    // Get Domain
    NSString *domain = root ? @"system" : [NSString stringWithFormat:@"gui/%@", @(PGUser.current.uid)];

    // Execute
    NSString *command = [NSString stringWithFormat:@"launchctl bootout \"%@/%@\"", domain, name];
    return [PGProcess runShellCommand:command forRootUser:root auth:auth error:error];

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

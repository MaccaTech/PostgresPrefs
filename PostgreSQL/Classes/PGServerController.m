//
//  PGServerController.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 7/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGServerController.h"

#pragma mark - Constants

NSString *const PGServerCheckStatusName = @"Check Status";
NSString *const PGServerQuickStatusName = @"Quick Status";
NSString *const PGServerStartName       = @"Start";
NSString *const PGServerStopName        = @"Stop";
NSString *const PGServerCreateName      = @"Create";
NSString *const PGServerDeleteName      = @"Delete";



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
 * The key method - applies the regex search/replace to the string.
 */
- (void)apply:(NSMutableString *)string;

@end



/**
 * Utility class for parsing launchctl output
 */
@interface PGLaunchctl : NSObject
/**
 * Converts the output of running `launchctl list <file>` to a dictionary of properties.
 */
+ (NSDictionary *)parseListOutput:(NSString *)output;
@end



@interface PGServerController()

/**
 * Called before running the action
 */
- (void)willRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus;

/**
 * Called after running the action
 */
- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus output:(NSString *)output error:(NSString *)error authStatus:(OSStatus)authStatus;

/**
 * Generates the start/stop/check status command to run on the shell
 */
- (NSString *)shellCommandForAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization;

/**
 * Generates the quick check status command to run on the shell
 */
- (NSString *)shellCommandForQuickStatus:(PGServer *)server authorization:(AuthorizationRef)authorization;

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



#pragma mark - PGLaunchctl

@implementation PGLaunchctl

+ (NSDictionary *)parseListOutput:(NSString *)output
{
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
    NSError *error;
    NSDictionary *result = JsonToDictionary(outputAsJSON, error);
    if (error) DLog(@"%@\n\n%@", outputAsJSON, error);
    return result;
}

@end



#pragma mark - PGServerController

@implementation PGServerController

- (id)initWithDelegate:(id<PGServerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

- (AuthorizationRights *)authorizationRights
{
    return [PGProcess authorizationRights];
}

#pragma mark Main Methods

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    [self runAction:action server:server authorization:authorization succeeded:nil failed:nil];
}

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization succeeded:(void (^)(void))succeeded failed:(void (^)(NSString *))failed
{
    // Cache the existing status, because may need to revert to it if errors
    PGServerStatus previousStatus = server.status;
    
    // If doing a quick check status, don't show a spinning wheel,
    // and don't remove the existing error until finished
    if (action != PGServerQuickStatus) {
        server.error = nil;
        server.processing = YES;
    }

    NSString *command = [self shellCommandForAction:action server:server authorization:authorization];
    NSString *result = nil;
    NSString *error = nil;
    OSStatus authStatus = errAuthorizationSuccess;
    
    // Update server before action
    [self willRunAction:action server:server previousStatus:previousStatus];
    
    // Notify delegate
    [self.delegate postgreServer:server willRunAction:action];
    
    @try {
        // One at a time
        @synchronized(server) {
            result = [PGProcess runShellCommand:command withArgs:nil authorization:authorization authStatus:&authStatus];
        }
    }
    @catch (NSException *err) {
        error = [NSString stringWithFormat:@"Error: %@\n%@", [err name], [err reason]];
    }
    @finally {
        
        // Don't change spinning wheel if just doing a quick-check status
        if (action != PGServerQuickStatus) server.processing = NO;
        
        // Update server after action (including setting error if necessary)
        [self didRunAction:action server:server previousStatus:previousStatus output:result error:error authStatus:authStatus];
        
        // Notify delegate
        if (NonBlank(server.error)) {
            if (failed) failed(server.error);
            else [self.delegate postgreServer:server didFailAction:action error:server.error];
        } else {
            if (succeeded) succeeded();
            else [self.delegate postgreServer:server didSucceedAction:action];
        }
        [self.delegate postgreServer:server didRunAction:action];
    }
}



#pragma mark Private

- (void)willRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus
{
    switch (action) {
        case PGServerStart: server.status = PGServerStarting; break;
        case PGServerStop: server.status = PGServerStopping; break;
        case PGServerDelete: // Fall through
        case PGServerCreate: server.status = PGServerUpdating; break;
        default: break;
    }
}

- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus output:(NSString *)output error:(NSString *)error authStatus:(OSStatus)authStatus
{
    // Start or Stop
    if (action == PGServerStart || action == PGServerStop || action == PGServerCreate || action == PGServerDelete) {
        
        // Auth error
        if (authStatus != errAuthorizationSuccess) {
            server.status = previousStatus;
            server.error = @"Authorization required!";
            
        // Error was thrown
        } else if (error) {
            server.status = previousStatus;
            server.error = error;
            
        // If the command returned anything, it must be an error
        } else if (output) {
            server.status = previousStatus;
            server.error = output;
        
        // Succeeded
        } else {
            switch (action) {
                // Will always call check status afterwards to confirm if really did start
                case PGServerStart: server.status = PGServerStarting; break;
                case PGServerStop: server.status = PGServerStopped; break;
                case PGServerDelete: server.status = PGServerStopped; break;
                case PGServerCreate: if (server.status == PGServerUpdating) server.status = previousStatus; break;
                default: server.status = PGServerStatusUnknown;
            }
        }
    
    // Check status
    } else if (action == PGServerCheckStatus || action == PGServerQuickStatus) {
        
        PGServerStatus existingStatus = server.status;
        NSString *existingError = server.error;
        
        // Auth error
        if (authStatus != errAuthorizationSuccess) {
            DLog(@"Authorization error: %d", authStatus);
            
        // Error was thrown
        } else if (error) {
            server.status = PGServerStatusUnknown;
            server.error = error;
            
        // Empty output
        } else if (!NonBlank(output)) {
            server.status = PGServerStatusUnknown;
            server.error = @"Unrecognized response from launchctl";
            
        // Not loaded
        } else if ([output rangeOfString:@"unknown response"].location != NSNotFound || [output rangeOfString:@"Could not find service"].location != NSNotFound) {
            server.status = PGServerStopped;
            
        // Output is not in plist format
        } else if (![output hasPrefix:@"{"]) {
            server.status = PGServerStatusUnknown;
            server.error = output;
            
        // Parse plist output
        } else {
            NSDictionary *plist = [PGLaunchctl parseListOutput:output];
            if (!plist) {
                server.status = PGServerStatusUnknown;
                server.error = @"Unrecognized response from launchctl";
                
            } else {
                NSString *pid = ToString(plist[@"PID"]);
            
                // Not running
                if (!NonBlank(pid)) {
                    server.status = PGServerRetrying;
                    
                // Running, but check if running with correct settings
                } else {
                    server.status = PGServerStarted;
                    server.error = [self errorFromRunningStatus:plist forServer:server];
                }
            }
        }
        
        // Don't "lose" the existing error details if doing a quick status check
        // and the status hasn't changed
        // Note that quick status doesn't do all the checks that check status does
        BOOL statusChanged = server.status != existingStatus;
        if (!statusChanged && action == PGServerQuickStatus) server.error = existingError;
    }
    
    if (IsLogging) {
        DLog(@"[%@] %@ : %@%@", server.name, ServerActionDescription(action), ServerStatusDescription(server.status), (server.error?[NSString stringWithFormat:@"\n\n[error] %@", server.error]:@""));
    }
}

- (NSString *)errorFromRunningStatus:(NSDictionary *)status forServer:(PGServer *)server
{
    NSString *binDirectory = nil;
    NSString *dataDirectory = nil;
    NSString *port = nil;
    NSUInteger index = 0;
    
    // Parse Bin Directory
    NSArray *programArgs = ToArray(status[@"ProgramArguments"]);
    if (programArgs.count > 0) binDirectory = [ToString(programArgs[0]) stringByDeletingLastPathComponent];
    
    // Parse Data Directory
    index = [programArgs indexOfObject:@"-D"];
    if (index != NSNotFound && index+1 < programArgs.count) dataDirectory = programArgs[index+1];
    
    // Parse Port
    index = [programArgs indexOfObject:@"-p"];
    if (index != NSNotFound && index+1 < programArgs.count) port = programArgs[index+1];
    
    // Validate Bin Directory
    if (NonBlank(binDirectory) && ![[binDirectory stringByExpandingTildeInPath] isEqualToString:[server.settings.binDirectory stringByExpandingTildeInPath]]) return @"Running with different bin directory!";
    
    // Validate Data Directory
    if (NonBlank(dataDirectory) && ![[dataDirectory stringByExpandingTildeInPath] isEqualToString:[server.settings.dataDirectory stringByExpandingTildeInPath]]) return @"Running with different data directory!";
    
    // Validate Port
    if (NonBlank(port) && ![port isEqualToString:server.settings.port]) return [NSString stringWithFormat:@"Running on port %@!", port];
    
    return nil;
}

- (NSString *)shellCommandForAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    if (action == PGServerQuickStatus) return [self shellCommandForQuickStatus:server authorization:authorization];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"PGPrefsPostgreSQL" ofType:@"sh"];
    NSString *result = path;
    
    // Name
    if (NonBlank(server.name)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGNAME=%@\"", server.fullName]];
    }
    // Username
    if (NonBlank(server.settings.username)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGUSER=%@\"", server.settings.username]];
    }
    // Data Directory
    if (NonBlank(server.settings.dataDirectory)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGDATA=%@\"", server.settings.dataDirectory]];
    }
    // Data Port
    if (NonBlank(server.settings.port)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGPORT=%@\"", server.settings.port]];
    }
    // Bin Directory
    if (NonBlank(server.settings.binDirectory)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGBIN=%@\"", server.settings.binDirectory]];
    }
    // Log File
    if (NonBlank(server.settings.logFile)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGLOG=%@\"", server.settings.logFile]];
    }
    
    // Startup
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --PGSTART=%@", ServerStartupDescription(server.settings.startup) ]];
    
    // Debug
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --DEBUG=%@", (IsLogging ? @"Yes" : @"No") ]];
    
    // Action
    NSString *actionString = nil;
    switch (action) {
        case PGServerQuickStatus: // Fall through
        case PGServerCheckStatus: actionString = @"status"; break;
        case PGServerStart: actionString = @"start"; break;
        case PGServerStop: actionString = @"stop"; break;
        case PGServerCreate: actionString = @"create"; break;
        case PGServerDelete: actionString = @"delete"; break;
    }
    result = [result stringByAppendingString:[NSString stringWithFormat:@" %@", actionString]];
    
    return result;
}

- (NSString *)shellCommandForQuickStatus:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    // Basic command
    NSString *result = [NSString stringWithFormat:@"launchctl list \"%@.%@\"", PGPrefsAppID, server.name];
    
    // Now work out if we need to switch user
    BOOL shouldRunAsRoot = server.needsAuthorization;
    
    // Will run as root
    if (authorization != NULL) {
        if (!shouldRunAsRoot) result = [NSString stringWithFormat:@"su \"%@\" -c '%@'", NSUserName(), result];
        
    // Will run as current user
    } else {
        if (shouldRunAsRoot) DLog(@"*** ERROR *** Needs to run as root: %@", server.name);
    }
    
    return result;
}

@end

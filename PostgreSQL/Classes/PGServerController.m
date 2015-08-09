//
//  PGServerController.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 7/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGServerController.h"

#pragma mark - Constants / Functions

NSString *const PGServerCheckStatusName = @"Check Status";
NSString *const PGServerStartName       = @"Start";
NSString *const PGServerStopName        = @"Stop";
NSString *const PGServerCreateName      = @"Create";
NSString *const PGServerDeleteName      = @"Delete";

CG_INLINE BOOL
EqualPaths(NSString *path1, NSString *path2)
{
    path1 = TrimToNil(path1);
    path2 = TrimToNil(path2);
    if (!path1 && !path2) return YES;
    
    return [[path1 stringByStandardizingPath] isEqualToString:[path2 stringByStandardizingPath]];
}

CG_INLINE BOOL
EqualUsernames(NSString *user1, NSString *user2)
{
    user1 = TrimToNil(user1);
    user2 = TrimToNil(user2);
    if ([user1 isEqualToString:NSUserName()]) user1 = nil;
    if ([user2 isEqualToString:NSUserName()]) user2 = nil;
    
    if (!user1 && !user2) return YES;
    return [user1 isEqualToString:user2];
}



#pragma mark - Interfaces

@interface PGServerController()

/**
 * Called before running the action
 */
- (void)willRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus;

/**
 * Called after running the action if authorization failed
 */
- (void)didFailAuthForAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus authStatus:(OSStatus)authStatus;

/**
 * Called after running the action if an error occurred
 */
- (void)didFailAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus error:(NSString *)error;

/**
 * Called after running the action
 */
- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus result:(id)result;

/**
 * Generates the start/stop/create/delete command to run on the shell
 */
- (NSString *)shellCommandForAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization;

/**
 * Populates all derived properties of server after initial creation.
 */
- (void)initServer:(PGServer *)server;

/**
 * Standardizes settings and validates.
 */
- (void)initSettings:(PGServer *)server;

/**
 * Sets the server status and error, and makes any required changes to other properties.
 */
- (void)setStatus:(PGServerStatus)status error:(NSString *)error forServer:(PGServer *)server;

/**
 * Splits the full name into its component parts
 */
- (void)partsBySplittingFullName:(NSString *)fullName user:(NSString **)user name:(NSString **)name domain:(NSString **)domain;
/**
 * Joins the component parts into a full name
 */
- (NSString *)fullNameByJoiningUser:(NSString *)user name:(NSString *)name domain:(NSString *)domain;

@end



#pragma mark - PGServerController

@implementation PGServerController

#pragma mark Properties

- (AuthorizationRights *)authorizationRights
{
    return [PGProcess authorizationRights];
}



#pragma mark Main Methods

- (BOOL)shouldCheckStatusForServer:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    if (!server) return NO;
    if (server.processing) return NO;
    
    return YES;
}

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    [self runAction:action server:server authorization:authorization succeeded:nil failed:nil];
}

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization succeeded:(void (^)(void))succeeded failed:(void (^)(NSString *error))failed
{
    id result = nil;
    NSString *error = nil;
    OSStatus authStatus = errAuthorizationSuccess;
    
    // Cache the existing status, because may need to revert to it if errors
    PGServerStatus previousStatus = server.status;
    
    // If doing a check status, don't show a spinning wheel,
    // and don't remove the existing error until finished
    if (action != PGServerCheckStatus) {
        server.error = nil;
        server.processing = YES;
    }

    // Update server before action
    [self willRunAction:action server:server previousStatus:previousStatus];
    
    // Notify delegate
    [self.delegate postgreServer:server willRunAction:action];
    
    // Check status
    if (action == PGServerCheckStatus) {
        @synchronized(server) {
            result = [self loadedServerWithName:server.daemonName forRootUser:server.daemonInRootContext authorization:authorization authStatus:&authStatus error:&error];
        }
        
    // Stop
    } else if (action == PGServerStop) {

        @synchronized(server) {
            [PGLaunchd stopDaemonWithName:server.daemonName forRootUser:server.daemonInRootContext authorization:authorization authStatus:&authStatus error:&error];
        }
        
    // Start external
    } else if (action == PGServerStart && server.external) {
        
        @synchronized(server) {
            [PGLaunchd startDaemonWithFile:server.daemonFile forRootUser:server.daemonInRootContext authorization:authorization authStatus:&authStatus error:&error];
        }
        
        
    // Other actions
    } else {
        NSString *command = [self shellCommandForAction:action server:server authorization:authorization];
        NSString *output = nil;
        
        // Execute
        @synchronized(server) {
            [PGProcess runShellCommand:command authorization:authorization authStatus:&authStatus output:&output error:&error];
        }
        
        result = output;
    }
    
    // Don't change spinning wheel if just doing a check status
    if (action != PGServerCheckStatus) server.processing = NO;
    
    // Auth error
    if (authStatus != errAuthorizationSuccess) {
        [self didFailAuthForAction:action server:server previousStatus:previousStatus authStatus:authStatus];
     
    // Error
    } else if (error) {
        [self didFailAction:action server:server previousStatus:previousStatus error:error];
        
    // Check result
    } else {
        [self didRunAction:action server:server previousStatus:previousStatus result:result];
    }
    
    // Log
    if (IsLogging) {
        DLog(@"[%@] %@ : %@%@", server.name, ServerActionDescription(action), ServerStatusDescription(server.status), (server.error?[NSString stringWithFormat:@"\n\n[error] %@", server.error]:@""));
    }
    
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

- (PGServer *)loadedServerWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString *__autoreleasing *)error
{
    NSDictionary *daemon = [PGLaunchd loadedDaemonWithName:name forRootUser:root authorization:authorization authStatus:authStatus error:error];
    return [self serverFromDaemon:daemon forRootUser:root];
}

- (PGServer *)serverFromDaemonFile:(NSString *)file
{
    if (!FileExists(file)) return nil;
    
    NSDictionary *daemon = [[NSDictionary alloc] initWithContentsOfFile:[file stringByExpandingTildeInPath]];
    PGServer *result = [self serverFromDaemon:daemon];
    return result;
}

- (PGServer *)serverFromDaemon:(NSDictionary *)daemon forRootUser:(BOOL)root
{
    PGServer *result = [self serverFromDaemon:daemon];
    if (result.external) {
        if (root) {
            result.daemonAllowedContext = PGServerDaemonContextRootOnly;
            result.name = [NSString stringWithFormat:@"root@%@", result.name];
        } else {
            result.daemonAllowedContext = PGServerDaemonContextUserOnly;
        }
    }
    return result;
}

- (PGServer *)serverFromDaemon:(NSDictionary *)daemon
{
    if (daemon.count == 0) return nil;
    
    DLog(@"Daemon: %@", daemon);
    
    NSString *daemonName = TrimToNil(ToString(daemon[@"Label"]));
    NSString *daemonUsername = TrimToNil(ToString(daemon[@"UserName"]));
    NSArray *daemonProgramArgs = ToArray(daemon[@"ProgramArguments"]);
    NSDictionary *daemonEnvironmentVars = ToDictionary(daemon[@"EnvironmentVariables"]);
    NSString *daemonStdout = TrimToNil(ToString(daemon[@"StandardOutPath"]));
    NSString *daemonStderr = TrimToNil(ToString(daemon[@"StandardErrorPath"]));
    NSString *daemonWorkingDir = TrimToNil(ToString(daemon[@"WorkingDirectory"]));
    
    NSUInteger index; // Used during parse
    
    // Name & Domain
    if (!daemonName) return nil;
    NSString *name = nil;
    NSString *domain = nil;
    BOOL externalServer = NO;
    
    // Internal Server
    if ([daemonName hasPrefix:[PGPrefsAppID stringByAppendingString:@"."]]) {
        name = [daemonName substringFromIndex:PGPrefsAppID.length+1];
        domain = PGPrefsAppID;

    // External Server
    } else {
        name = daemonName;
        [self partsBySplittingFullName:daemonName user:nil name:nil domain:&domain];
        externalServer = YES;
    }
    
    // Username
    NSString *username = daemonUsername;
    
    // Bin Directory
    if (daemonProgramArgs.count == 0) return nil;
    NSString *filepath = ToString(daemonProgramArgs[0]);
    NSString *executable = [filepath lastPathComponent];
    
    // Abort if not a Postgres agent, unless created by this tool
    if (externalServer && !(
       [executable isEqualToString:@"postgres"] ||
       [executable isEqualToString:@"pg_ctl"] ||
       [executable isEqualToString:@"postmaster"])
    ) return nil;
    NSString *binDirectory = [filepath stringByDeletingLastPathComponent];
    
    // Data Directory
    NSString *dataDirectory = nil;
    index = [daemonProgramArgs indexOfObject:@"-D"];
    if (index != NSNotFound && index+1 < daemonProgramArgs.count) {
        dataDirectory = ToString(daemonProgramArgs[index+1]);
    }
    if (!NonBlank(dataDirectory)) {
        for (NSString *daemonProgramArg in daemonProgramArgs) {
            NSString *arg = TrimToNil(daemonProgramArg);
            if ([arg hasPrefix:@"-D"]) dataDirectory = [arg substringFromIndex:2];
        }
    }
    if (!NonBlank(dataDirectory)) {
        dataDirectory = ToString(daemonEnvironmentVars[@"PGDATA"]);
    }
    if (!NonBlank(dataDirectory)) {
        dataDirectory = daemonWorkingDir;
    }
    
    // Log File
    NSString *logFile = nil;
    index = [daemonProgramArgs indexOfObject:@"-r"];
    if (index != NSNotFound && index+1 < daemonProgramArgs.count) {
        logFile = ToString(daemonProgramArgs[index+1]);
    }
    // Only use STDOUT/STDERR if agent was not created by this tool
    if (!NonBlank(logFile) && externalServer) {
        logFile = ToString(daemonStderr);
        if (!NonBlank(logFile)) logFile = ToString(daemonStdout);
    }
    
    // Port
    NSString *port = nil;
    index = [daemonProgramArgs indexOfObject:@"-p"];
    if (index != NSNotFound && index+1 < daemonProgramArgs.count) {
        port = ToString(daemonProgramArgs[index+1]);
    }
    if (!NonBlank(port)) {
        port = ToString(daemonEnvironmentVars[@"PGPORT"]);
    }
    
    // Startup
    
    // Create server
    PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:username binDirectory:binDirectory dataDirectory:dataDirectory logFile:logFile port:port startup:PGServerStartupManual];
    PGServer *server = [self serverFromSettings:settings name:name domain:domain];
    
    // Set status
    NSString *pid = ToString(daemon[@"PID"]);
    server.status = NonBlank(pid) ? PGServerStarted : PGServerRetrying;
    
    return server;
}

- (NSDictionary *)daemonFromServer:(PGServer *)server
{
    NSMutableArray *programArgs = nil;
    if (server.settings.binDirectory) {
        [programArgs addObject:[NSString stringWithFormat:@"%@/postgres", server.settings.binDirectory]];
        if (server.settings.dataDirectory) {
            [programArgs addObject:@"-D"];
            [programArgs addObject:server.settings.dataDirectory];
        }
        if (server.settings.port) {
            [programArgs addObject:@"-p"];
            [programArgs addObject:server.settings.port];
        }
        if (server.settings.logFile) {
            [programArgs addObject:@"-r"];
            [programArgs addObject:server.settings.logFile];
        }
    }
    
    return @{
             @"Label":server.daemonName?:@"",
             @"UserName":server.settings.username?:@"",
             @"ProgramArguments":programArgs?:@[],
             @"WorkingDirectory":server.settings.dataDirectory?:@"",
             @"StandardOutPath":server.daemonLog?:@"",
             @"StandardErrorPath":server.daemonLog?:@"",
             @"Disabled":[NSNumber numberWithBool:server.settings.startup==PGServerStartupManual],
             @"RunAtLoad":[NSNumber numberWithBool:server.settings.startup!=PGServerStartupManual],
             @"KeepAlive":[NSNumber numberWithBool:YES]
    };
}

- (NSDictionary *)propertiesFromServer:(PGServer *)server
{
    return server.properties;
}

- (PGServer *)serverFromProperties:(NSDictionary *)properties name:(NSString *)name
{
    if (![PGServer hasAllKeys:properties]) return nil;
    
    PGServer *server = [[PGServer alloc] initWithName:name domain:nil];
    server.properties = properties;
    
    [self initServer:server];

    return server;
}

- (PGServer *)serverFromSettings:(PGServerSettings *)settings name:(NSString *)name domain:(NSString *)domain
{
    PGServer *server = [[PGServer alloc] initWithName:name domain:domain settings:settings];
    
    [self initServer:server];
    
    return server;
}

- (BOOL)setName:(NSString *)name forServer:(PGServer *)server
{
    if (!NonBlank(name)) return NO;
    if ([name isEqualToString:server.name]) return NO;
    if (server.external) return NO;
    
    server.name = name;
    server.shortName = name;
    server.daemonName = [NSString stringWithFormat:@"%@.%@", PGPrefsAppID, server.name];
    
    return YES;
}

- (BOOL)setStartup:(PGServerStartup)startup forServer:(PGServer *)server
{
    if ([self toCorrectStartup:startup forServer:server] != startup) return NO;
    
    server.settings.startup = startup;
    
    return YES;
}

- (void)setDirtySetting:(NSString *)setting value:(NSString *)value forServer:(PGServer *)server
{
    PGServerSettings *cleanSettings = server.settings;
    PGServerSettings *dirtySettings = server.dirtySettings;
    BOOL dirty = NO;
    if ([setting isEqualToString:PGServerUsernameKey]) {
        dirtySettings.username = value;
        dirty = !BothNilOrEqual(cleanSettings.username, dirtySettings.username);
    } else if ([setting isEqualToString:PGServerPortKey]) {
        dirtySettings.port = value;
        dirty = !BothNilOrEqual(cleanSettings.port, dirtySettings.port);
    } else if ([setting isEqualToString:PGServerBinDirectoryKey]) {
        dirtySettings.binDirectory = value;
        dirty = !BothNilOrEqual(cleanSettings.binDirectory, dirtySettings.binDirectory);
    } else if ([setting isEqualToString:PGServerDataDirectoryKey]) {
        dirtySettings.dataDirectory = value;
        dirty = !BothNilOrEqual(cleanSettings.dataDirectory, dirtySettings.dataDirectory);
    } else if ([setting isEqualToString:PGServerLogFileKey]) {
        dirtySettings.logFile = value;
        dirty = !BothNilOrEqual(cleanSettings.logFile, dirtySettings.logFile);
    } else return;
    
    server.dirty = server.dirty || dirty;
    
    [self validateServerSettings:dirtySettings];
}

- (void)setDirtySettings:(PGServerSettings *)settings forServer:(PGServer *)server
{
    // Overwrite all dirty settings, apart from startup
    PGServerSettings *newSettings = [PGServerSettings settingsWithSettings:settings];
    newSettings.startup = server.dirtySettings.startup;
    server.dirtySettings = newSettings;
    
    // Update dirty flag
    server.dirty = ![server.dirtySettings isEqualToSettings:server.settings];
    
    // Validate
    [self validateServerSettings:server.dirtySettings];
}

- (void)setSettings:(PGServerSettings *)settings forServer:(PGServer *)server
{
    // Overwrite all settings, apart from startup
    PGServerSettings *newSettings = [PGServerSettings settingsWithSettings:settings];
    newSettings.startup = server.settings.startup;
    server.settings = newSettings;

    // Update dirty flag
    server.dirty = ![server.dirtySettings isEqualToSettings:server.settings];
    
    // Configure and validate
    [self initSettings:server];
}

- (void)clean:(PGServer *)server
{
    [server.dirtySettings importAllSettings:server.settings];
    server.dirty = NO;
}

- (void)setStatus:(PGServerStatus)status error:(NSString *)error forServer:(PGServer *)server
{
    PGServerStatus oldStatus = server.status;
    NSString *oldError = server.error;
    
    if (error) server.error = TrimToNil(error);
    server.status = status;
    
    if (oldStatus != server.status ||
        oldError != server.error ||
        ![oldError isEqualToString:server.error])
    {
        [self.delegate didChangeServerStatus:server];
    }
}

- (void)initServer:(PGServer *)server
{
    // Internal vs External based on domain
    server.external = NonBlank(server.domain) &&
        ![server.domain isEqualToString:PGPrefsAppID];
    
    // Internal
    if (!server.external) {
        server.domain = PGPrefsAppID; // Might have been blank
        server.shortName = server.name;
        server.daemonName = [NSString stringWithFormat:@"%@.%@", PGPrefsAppID, server.name];
        
    // External
    } else {
        NSString *shortName = nil;
        [self partsBySplittingFullName:server.name user:nil name:&shortName domain:nil];
        server.shortName = shortName ?: server.name;
        server.daemonName = server.name;
    }
    
    [self initSettings:server];
}
- (void)initSettings:(PGServer *)server
{
    PGServerSettings *settings = server.settings;
    settings.username = [settings.username isEqualToString:NSUserName()] ? nil : settings.username;
    settings.binDirectory = [settings.binDirectory stringByAbbreviatingWithTildeInPath];
    settings.dataDirectory = [settings.dataDirectory stringByAbbreviatingWithTildeInPath];
    settings.logFile = [settings.logFile stringByAbbreviatingWithTildeInPath];
    settings.port = settings.port.integerValue == 0 ? nil : settings.port;
    settings.startup = [self toCorrectStartup:settings.startup forServer:server];
    
    [self validateServerSettings:settings];
}
- (PGServerStartup)toCorrectStartup:(PGServerStartup)startup forServer:(PGServer *)server
{
    // If daemon runs as a different user, startup at login is impossible
    if (server.settings.hasDifferentUser) {
        if (startup == PGServerStartupAtLogin) return PGServerStartupAtBoot;
    }
    
    return startup;
}
- (void)validateServerSettings:(PGServerSettings *)settings
{
    settings.invalidUsername = NonBlank(settings.username) && [settings.username rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound;
    settings.invalidBinDirectory = !NonBlank(settings.binDirectory) || ![NSURL URLWithString:settings.binDirectory];
    settings.invalidDataDirectory = !NonBlank(settings.dataDirectory) || ![NSURL URLWithString:settings.dataDirectory];
    settings.invalidLogFile = NonBlank(settings.logFile) && ![NSURL URLWithString:settings.logFile];
    settings.invalidPort = NonBlank(settings.port) && settings.port.integerValue == 0;
}



#pragma mark Private

- (void)willRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus
{
    switch (action) {
        case PGServerStart:       server.status = PGServerStarting; break;
        case PGServerStop:        server.status = PGServerStopping; break;
        case PGServerDelete:      server.status = PGServerUpdating; break;
        case PGServerCreate:      server.status = PGServerUpdating; break;
        case PGServerCheckStatus: break; // Do nothing
    }
}

- (void)didFailAuthForAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus authStatus:(OSStatus)authStatus
{
    switch (action) {
        case PGServerStart:  // Fall thorugh
        case PGServerStop:   // Fall thorugh
        case PGServerCreate: // Fall thorugh
        case PGServerDelete: // Fall thorugh
            server.status = previousStatus;
            server.error = @"Authorization required!";
            break;
        case PGServerCheckStatus:
            DLog(@"Authorization error: %d", authStatus);
            break;
    }
}

- (void)didFailAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus error:(NSString *)error
{
    switch (action) {
        case PGServerStart:  // Fall thorugh
        case PGServerStop:   // Fall thorugh
        case PGServerCreate: // Fall thorugh
        case PGServerDelete: // Fall thorugh
            server.status = previousStatus;
            server.error = error;
            break;
        case PGServerCheckStatus:
            server.status = PGServerStatusUnknown;
            server.error = error;
            break;
    }
}

- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus result:(id)result
{
    // Start or Stop
    if (action == PGServerStart || action == PGServerStop || action == PGServerCreate || action == PGServerDelete) {
        
        NSString *output = ToString(result);
        
        // If the command returned anything, it must be an error
        if (output) {
            [self didFailAction:action server:server previousStatus:previousStatus error:output];
        
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
    } else if (action == PGServerCheckStatus) {
        
        // Daemon not loaded
        if (!result || ![result isKindOfClass:[PGServer class]]) {
            server.status = PGServerStopped;
            
        // Agent is loaded
        } else {
            // Check settings match what we expect
            PGServer *loaded = (PGServer *)result;
            [self setStatus:loaded.status error:nil forServer:server];
            
            // Validate Bin Directory
            if (NonBlank(loaded.settings.binDirectory) && !EqualPaths(loaded.settings.binDirectory, server.settings.binDirectory)) {
                server.error = @"Running with different bin directory!";
            
            // Validate Data Directory
            } else if (NonBlank(loaded.settings.dataDirectory) && !EqualPaths(loaded.settings.dataDirectory, server.settings.dataDirectory)) {
                server.error = @"Running with different data directory!";
            
            // Validate Port
            } else if (NonBlank(loaded.settings.port) && loaded.settings.port != server.settings.port && ![loaded.settings.port isEqualToString:server.settings.port]) {
                if (NonBlank(loaded.settings.port)) server.error = [NSString stringWithFormat:@"Running on port %@!", loaded.settings.port];
                else
                    server.error = @"Running on a different port!";
            
            // Validate Username
            } else if (NonBlank(loaded.settings.username) && !EqualUsernames(loaded.settings.username, server.settings.username)) {
                if (NonBlank(loaded.settings.username)) server.error = [NSString stringWithFormat:@"Running as user %@", loaded.settings.username];
                else server.error = @"Running as a different user!";
            }
        }
    }
}

- (NSString *)shellCommandForAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    if (action == PGServerCheckStatus) return nil;
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"PGPrefsPostgreSQL" ofType:@"sh"];
    NSString *result = path;
    
    // Name
    if (NonBlank(server.name)) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGNAME=%@\"", server.daemonName]];
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
        case PGServerStart: actionString = @"start"; break;
        case PGServerStop: actionString = @"stop"; break;
        case PGServerCreate: actionString = @"create"; break;
        case PGServerDelete: actionString = @"delete"; break;
        default:
            @throw [NSException exceptionWithName:@"ProgramError" reason:@"Program error - unhandled action!" userInfo:nil];
            break;
    }
    result = [result stringByAppendingString:[NSString stringWithFormat:@" %@", actionString]];
    
    return result;
}

- (void)partsBySplittingFullName:(NSString *)fullName user:(NSString **)user name:(NSString **)name domain:(NSString **)domain
{
    if (!user && !name && !domain) return;
    fullName = TrimToNil(fullName);
    if (!fullName) {
        if (user) *user = nil;
        if (name) *name = nil;
        if (domain) *domain = nil;
    }
    
    // Name may end in a version number, e.g. com.blah.postgressql-9.4
    // So the final dot may not be a real "package-separator"
    // Hence the need for an ugly regex...
    static NSRegularExpression *regex = nil;
    if (!regex) regex = [NSRegularExpression regularExpressionWithPattern:@"\\A(?:(\\w+)@)?(\\S*)\\.([^\\.]*[\\p{Ll}\\p{Lu}\\p{Lt}\\p{Lo}]\\S*?)\\s*\\z" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    
    NSTextCheckingResult *result = [regex firstMatchInString:fullName options:0 range:NSMakeRange(0,fullName.length)];
    
    NSString *userResult;
    if (result.numberOfRanges <= 1 || [result rangeAtIndex:1].location == NSNotFound)
        userResult = nil;
    else
        userResult = [fullName substringWithRange:[result rangeAtIndex:1]];
    
    NSString *domainResult;
    if (result.numberOfRanges <= 2 || [result rangeAtIndex:2].location == NSNotFound)
        domainResult = nil;
    else
        domainResult = [fullName substringWithRange:[result rangeAtIndex:2]];
    
    NSString *nameResult;
    if (result.numberOfRanges <= 3 || [result rangeAtIndex:3].location == NSNotFound)
        nameResult = nil;
    else
        nameResult = [fullName substringWithRange:[result rangeAtIndex:3]];
    
    if (user) *user = userResult;
    if (domain) *domain = domainResult;
    if (name) *name = nameResult;
}
- (NSString *)fullNameByJoiningUser:(NSString *)user name:(NSString *)name domain:(NSString *)domain
{
    user = TrimToNil(user);
    name = TrimToNil(name);
    domain = TrimToNil(domain);
    NSString *result;
    if (!name) result = domain;
    else if (!domain) result = name;
    else [NSString stringWithFormat:@"%@.%@", domain, name];
    return user && result ? [NSString stringWithFormat:@"%@@%@", user, result] : result;
}

@end

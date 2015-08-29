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

@interface NSDictionary (Helper)
/// Returns a filtered copy of this dictionary, using the block to decide which keys to include
- (NSDictionary *)filteredDictionaryUsingBlock:(BOOL(^)(id key, id value))block;
@end

@implementation NSDictionary(Helper)
- (NSDictionary *)filteredDictionaryUsingBlock:(BOOL (^)(id, id))block
{
    NSArray *keysToKeep = [self.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id key, NSDictionary *bindings)
    {
        return block(key, self[key]);
    }]];
    
    if (keysToKeep == 0) return @{};
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:keysToKeep.count];
    for (id key in keysToKeep) result[key] = self[key];
    return [NSDictionary dictionaryWithDictionary:result];
}
@end



#pragma mark - Interfaces

@interface PGServerController()

/**
 * Called before running the action. Opportunity to abort action, e.g. if validation fails.
 */
- (BOOL)shouldRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus error:(NSString **)error;

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
- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus;

/**
 * Populates all derived properties of server after initial creation.
 */
- (void)initServer:(PGServer *)server;

/**
 * Standardizes settings and validates.
 */
- (void)initSettings:(PGServer *)server;

/**
 * Parse the program args used to launch postgres (in an agent file, or process lookup).
 */
- (void)populateSettings:(PGServerSettings *)settings fromProgramArgs:(NSArray *)args;

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

- (PGRights *)rights
{
    static PGRights *rights;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rights = [PGRights rightsWithArrayOfRights:@[PGProcess.rights, PGLaunchd.rights]];
    });
    return rights;
}



#pragma mark Main Methods

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization
{
    [self runAction:action server:server authorization:authorization succeeded:nil failed:nil];
}

- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization succeeded:(void (^)(void))succeeded failed:(void (^)(NSString *error))failed
{
    // Abort quickly
    if (!server) return;
    if (server.processing && action == PGServerCheckStatus) return;
    
    // One action at a time for a server
    @synchronized(server) {
    
    NSString *error = nil;
    OSStatus authStatus = errAuthorizationSuccess;
        
    // Cache the existing status, because may need to revert to it if errors
    PGServerStatus previousStatus = server.status;
        
    // Validate server settings
    if (![self shouldRunAction:action server:server previousStatus:previousStatus error:&error]) {
        server.error = error;
        if (failed) failed(server.error);
        else [self.delegate postgreServer:server didFailAction:action error:server.error];
        return;
    }
    
    // For some actions, don't show a spinning wheel,
    // and don't remove the existing error until finished
    if (! (action == PGServerCheckStatus || action == PGServerCreate) ) {
        server.error = nil;
        server.processing = YES;
    }

    // Notify delegate
    [self.delegate postgreServer:server willRunAction:action];
    
    // Execute
    switch (action) {
            
        case PGServerCheckStatus:
            [self checkStatusForServer:server];
            break;
            
        case PGServerStop:
            [self stopServer:server all:!server.external authorization:authorization authStatus:&authStatus error:&error];
            break;
            
        case PGServerStart:
            // Internal server
            if (!server.external) {
                // Validate
                if (![self validateSettingsForServer:server authorization:authorization authStatus:&authStatus error:&error]) break;
                // Unload
                if (![self stopServer:server all:YES authorization:authorization authStatus:&authStatus error:&error]) break;
                // Delete
                if (![self deleteDaemonFileForServer:server all:YES authorization:authorization authStatus:&authStatus error:&error]) break;
                // Create Daemon
                if (![self createDaemonFileForServer:server authorization:authorization authStatus:&authStatus error:&error]) break;
                // Create Log File
                if (![self createLogFileForServer:server authorization:authorization authStatus:&authStatus error:&error]) break;
                // Load
                [self loadDaemonForServer:server authorization:authorization authStatus:&authStatus error:&error];
                
            // External server
            } else {
                // Unload
                if (![self stopServer:server all:NO authorization:authorization authStatus:&authStatus error:&error]) break;
                // Load
                [self loadDaemonForServer:server authorization:authorization authStatus:&authStatus error:&error];
            }
            break;
            
        case PGServerDelete:
            if (![self stopServer:server all:!server.external authorization:authorization authStatus:&authStatus error:&error]) break;
            [self deleteDaemonFileForServer:server all:!server.external authorization:authorization authStatus:&authStatus error:&error];
            break;
            
        case PGServerCreate:
            if (server.external) {
                error = @"Program error - cannot create external server";
                break;
            }
            if (![self deleteDaemonFileForServer:server all:YES authorization:authorization authStatus:&authStatus error:&error]) break;
            [self createDaemonFileForServer:server authorization:authorization authStatus:&authStatus error:&error];
            break;
    }
    
    // Don't change spinning wheel for some actions
    if (! (action == PGServerCheckStatus || action == PGServerCreate))
        server.processing = NO;
    
    // Auth error
    if (authStatus != errAuthorizationSuccess) {
        [self didFailAuthForAction:action server:server previousStatus:previousStatus authStatus:authStatus];
     
    // Error
    } else if (error) {
        [self didFailAction:action server:server previousStatus:previousStatus error:error];
        
    // Check result
    } else {
        [self didRunAction:action server:server previousStatus:previousStatus];
    }
        
    } // End synchronized
    
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

- (BOOL)validateSettingsForServer:(PGServer *)server authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    PGServerSettings *settings = server.settings;
    [self validateServerSettings:settings];
    if (!settings.valid) {
        if (error) *error = @"Server settings are invalid";
        return NO;
    }

    // Username
    if (NonBlank(settings.username) && ![PGProcess runShellCommand:[NSString stringWithFormat:@"id -u %@", settings.username] forRootUser:YES authorization:authorization authStatus:authStatus error:error]) {
        settings.invalidUsername = @"No such user";
    }
    
    // Bin directory
    if (![PGFile dirExists:settings.binDirectory authorization:authorization authStatus:authStatus error:error]) {
        settings.invalidBinDirectory = @"No such directory";
    }

    
    // Data directory
    if (![PGFile dirExists:settings.dataDirectory authorization:authorization authStatus:authStatus error:error]) {
        settings.invalidDataDirectory = @"No such directory";
    }
    
    // Log directory
    if (NonBlank(settings.logFile) && ![PGFile dirExists:[settings.logFile stringByDeletingLastPathComponent] authorization:authorization authStatus:authStatus error:error]) {
        settings.invalidLogFile = @"No such directory";
    }
    
    if (!settings.valid) {
        if (error) *error = @"Server settings are invalid";
        return NO;
    }
    return YES;
}

- (BOOL)stopServer:(PGServer *)server all:(BOOL)all authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    if (![self unloadDaemonForServer:server all:all authorization:authorization authStatus:authStatus error:error]) return NO;
    
    if (!server.pid) return YES;
    
    // Check stopped
    PGProcess *process = [PGProcess runningProcessWithPid:server.pid];
    if (!process) return YES;
    
    // Still running - kill
    return [PGProcess kill:server.pid forRootUser:YES authorization:authorization authStatus:authStatus error:error];
}
- (BOOL)unloadDaemonForServer:(PGServer *)server all:(BOOL)all authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    if (![PGLaunchd stopDaemonWithName:server.daemonName forRootUser:server.daemonForAllUsers authorization:authorization authStatus:authStatus error:error]) return NO;
    
    if (!all) return YES;
    
    if (![PGLaunchd stopDaemonWithName:server.daemonName forRootUser:!server.daemonForAllUsers authorization:authorization authStatus:authStatus error:error]) return NO;
    
    return YES;
}
- (BOOL)loadDaemonForServer:(PGServer *)server authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    return [PGLaunchd startDaemonWithFile:server.daemonFile forRootUser:server.daemonForAllUsers authorization:authorization authStatus:authStatus error:error];
}
- (BOOL)deleteDaemonFileForServer:(PGServer *)server all:(BOOL)all authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    // Note that delete returns YES if the file is already deleted
    if (![PGFile deleteFile:server.daemonFile authorization:authorization authStatus:authStatus error:error]) return NO;
    
    if (!all) return YES;
    
    if (![PGFile deleteFile:server.daemonFileForAllUsersAtBoot authorization:authorization authStatus:authStatus error:error]) return NO;
    if (![PGFile deleteFile:server.daemonFileForAllUsersAtLogin authorization:authorization authStatus:authStatus error:error]) return NO;
    if (![PGFile deleteFile:server.daemonFileForCurrentUserOnly authorization:authorization authStatus:authStatus error:error]) return NO;

    return YES;
}
- (BOOL)createDaemonFileForServer:(PGServer *)server authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    NSDictionary *daemon = [self daemonFromServer:server];
    if (daemon.count == 0) return NO;
    
    return [PGFile createPlistFile:server.daemonFile contents:daemon owner:server.daemonForAllUsers?@"root":nil authorization:authorization authStatus:authStatus error:error];
}
- (BOOL)createLogFileForServer:(PGServer *)server authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error
{
    // Create Log Dir
    if (![PGFile createDir:[server.daemonLog stringByDeletingLastPathComponent] owner:(server.daemonForAllUsers?@"root":nil) authorization:authorization authStatus:authStatus error:error]) return NO;
    
    // Create Log File
    if (![PGFile createFile:server.daemonLog contents:nil owner:server.settings.username authorization:authorization authStatus:authStatus error:error]) return NO;
    
    return YES;
}

- (PGServer *)runningServerWithPid:(NSInteger)pid
{
    return [self serverFromProcess:[PGProcess runningProcessWithPid:pid]];
}

- (PGServer *)loadedServerWithName:(NSString *)name forRootUser:(BOOL)root
{
    NSDictionary *daemon = [PGLaunchd loadedDaemonWithName:name forRootUser:root];
    return [self serverFromDaemon:daemon forRootUser:root];
}

- (PGServer *)serverFromProcess:(PGProcess *)process
{
    if (!process) return nil;
    
    NSArray *args = [process.command componentsSeparatedByString:@" "];
    // Need to fix the problem of spaces in paths
    // E.g. ~/Library/Application Support/Postgres
    // This is incorrectly interpreted as 2 args
    NSMutableArray *programArgs = [NSMutableArray arrayWithCapacity:args.count];
    NSMutableString *buffer = [NSMutableString string];
    for (NSString *arg in args) {
        
        // New arg type, flush previous one
        if ([arg hasPrefix:@"-"] && arg.length == 2) {
            if (buffer.length > 0) {
                [programArgs addObject:[NSString stringWithString:buffer]];
                [buffer deleteCharactersInRange:NSMakeRange(0,buffer.length)];
            }
            [programArgs addObject:arg];
            
        // Append to previous string
        } else {
            [buffer appendString:@" "];
            [buffer appendString:arg];
        }
    }
    if (buffer.length > 0) [programArgs addObject:[NSString stringWithString:buffer]];
    
    PGServerSettings *settings = [[PGServerSettings alloc] init];
    [self populateSettings:settings fromProgramArgs:programArgs];
    if (!settings.binDirectory) return nil;
    
    NSString *name = [NSString stringWithFormat:@"localhost.[PID:%@]", @(process.pid)];
    PGServer *result = [self serverFromSettings:settings name:name domain:@"localhost"];
    result.pid = process.pid;
    result.status = PGServerStarted;
    return result;
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
            result.daemonAllowedContext = PGServerDaemonContextRoot;
            result.name = [NSString stringWithFormat:@"root@%@", result.name];
        } else {
            result.daemonAllowedContext = PGServerDaemonContextUser;
        }
    }
    return result;
}

- (PGServer *)serverFromDaemon:(NSDictionary *)daemon
{
    if (daemon.count == 0) return nil;
    
    DLog(@"Daemon: %@", daemon);
    
    NSString *daemonName = TrimToNil(ToString(daemon[@"Label"]));
    NSArray *daemonProgramArgs = ToArray(daemon[@"ProgramArguments"]);
    NSDictionary *daemonEnvironmentVars = ToDictionary(daemon[@"EnvironmentVariables"]);
    NSString *daemonStdout = TrimToNil(ToString(daemon[@"StandardOutPath"]));
    NSString *daemonStderr = TrimToNil(ToString(daemon[@"StandardErrorPath"]));
    NSString *daemonWorkingDir = TrimToNil(ToString(daemon[@"WorkingDirectory"]));
    NSString *daemonUsername = TrimToNil(ToString(daemon[@"UserName"]));
    
    PGServerSettings *settings = [[PGServerSettings alloc] init];
    
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
    
    // Parse Program Args
    [self populateSettings:settings fromProgramArgs:daemonProgramArgs];
    
    // No postgres executable found - abort if external
    if (!NonBlank(settings.binDirectory) && externalServer) return nil;
    
    // Data Directory
    if (!NonBlank(settings.dataDirectory)) {
        settings.dataDirectory = ToString(daemonEnvironmentVars[@"PGDATA"]);
    }
    if (!NonBlank(settings.dataDirectory)) {
        settings.dataDirectory = daemonWorkingDir;
    }
    
    // Log File
    // Only use STDOUT/STDERR if agent was not created by this tool
    if (!NonBlank(settings.logFile) && externalServer) {
        settings.logFile = ToString(daemonStderr);
        if (!NonBlank(settings.logFile)) settings.logFile = ToString(daemonStdout);
    }
    
    // Port
    if (!NonBlank(settings.port)) {
        settings.port = ToString(daemonEnvironmentVars[@"PGPORT"]);
    }
    
    // Username
    settings.username = daemonUsername;
    
    // Create server
    PGServer *server = [self serverFromSettings:settings name:name domain:domain];
    
    // Set status
    NSString *pid = ToString(daemon[@"PID"]);
    if (NonBlank(pid)) {
        server.status = PGServerStarted;
        server.pid = pid.integerValue;
    } else {
        server.status = PGServerRetrying;
    }
    
    return server;
}

- (NSDictionary *)daemonFromServer:(PGServer *)server
{
    // Must expand paths
    NSString *binDir = [server.settings.binDirectory stringByExpandingTildeInPath];
    NSString *dataDir = [server.settings.dataDirectory stringByExpandingTildeInPath];
    NSString *logFile = [server.settings.logFile stringByExpandingTildeInPath];
    NSString *daemonLog = [server.daemonLog stringByExpandingTildeInPath];
    
    // Generate program args
    NSMutableArray *programArgs = nil;
    if (binDir) {
        programArgs = [NSMutableArray array];
        [programArgs addObject:[binDir stringByAppendingString:@"/postgres"]];
        if (dataDir) {
            [programArgs addObject:@"-D"];
            [programArgs addObject:dataDir];
        }
        if (server.settings.port) {
            [programArgs addObject:@"-p"];
            [programArgs addObject:server.settings.port];
        }
        if (logFile) {
            [programArgs addObject:@"-r"];
            [programArgs addObject:logFile];
        }
    }
    
    return [@{
             @"Label":server.daemonName?:[NSNull null],
             @"UserName":server.daemonForAllUsers ? (server.settings.username?:NSUserName()) : [NSNull null],
             @"ProgramArguments":programArgs?:[NSNull null],
             @"WorkingDirectory":dataDir?:[NSNull null],
             @"StandardOutPath":daemonLog?:[NSNull null],
             @"StandardErrorPath":daemonLog?:[NSNull null],
             @"Disabled":[NSNumber numberWithBool:server.settings.startup==PGServerStartupManual],
             @"RunAtLoad":[NSNumber numberWithBool:server.settings.startup!=PGServerStartupManual],
             @"KeepAlive":@YES
    } filteredDictionaryUsingBlock:^BOOL(id key, id value) {
        return value != [NSNull null];
    }];
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
    
    [self validateServerSettings:settings];
}
- (void)validateServerSettings:(PGServerSettings *)settings
{
    [settings setValid];
    
    static NSCharacterSet *invalidUsernameCharacterSet;
    static NSCharacterSet *invalidPortCharacterSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
        [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        invalidUsernameCharacterSet = [validChars invertedSet];
        invalidPortCharacterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    });
    
    if (NonBlank(settings.username) && [settings.username rangeOfCharacterFromSet:invalidUsernameCharacterSet].location != NSNotFound) {
        settings.invalidUsername = @"Invalid characters";
    }
    if (!NonBlank(settings.binDirectory)) {
        settings.invalidBinDirectory = @"Value is required";
    } else if (![NSURL fileURLWithPath:[settings.binDirectory stringByExpandingTildeInPath] isDirectory:YES]) {
        settings.invalidBinDirectory = @"Path is invalid";
    }
    if (!NonBlank(settings.dataDirectory)) {
        settings.invalidDataDirectory = @"Value is required";
    } else if (![NSURL fileURLWithPath:[settings.dataDirectory stringByExpandingTildeInPath] isDirectory:YES]) {
        settings.invalidDataDirectory = @"Path is invalid";
    }
    if (NonBlank(settings.logFile) && ![NSURL fileURLWithPath:[settings.logFile stringByExpandingTildeInPath]]) {
        settings.invalidDataDirectory = @"Path is invalid";
    }
    if (NonBlank(settings.port)) {
        if ([settings.port rangeOfCharacterFromSet:invalidPortCharacterSet].location != NSNotFound ||
            settings.port.integerValue < 1 || settings.port.integerValue > 65536) {
            settings.invalidPort = @"Must be a number between 1 and 65536";
        }
    }
}



#pragma mark Private

- (BOOL)shouldRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus error:(NSString *__autoreleasing *)error
{
    // Validate settings before starting server
    if (action == PGServerStart) {
        [self validateServerSettings:server.settings];
        if (!server.settings.valid) {
            if (error) *error = @"Server settings are invalid";
            return NO;
        }
    }
    
    switch (action) {
        case PGServerStart:       server.status = PGServerStarting; break;
        case PGServerStop:        server.status = PGServerStopping; break;
        case PGServerDelete:      server.status = PGServerDeleting; break;
        case PGServerCreate:      break; // Do nothing
        case PGServerCheckStatus: break; // Do nothing
    }
    
    return YES;
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
        case PGServerCheckStatus: break; // Do nothing
    }
}

- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousStatus:(PGServerStatus)previousStatus
{
    switch (action) {
        // Will always call check status afterwards to confirm if really did start
        case PGServerStart: server.status = PGServerStarting; break;
        case PGServerStop: server.status = PGServerStopped; break;
        case PGServerDelete: server.status = PGServerStopped; break;
        case PGServerCreate: if (server.status == PGServerUpdating) server.status = previousStatus; break;
        case PGServerCheckStatus: break; // Do nothing
    }
}

- (void)checkStatusForServer:(PGServer *)server
{
    // Find loaded server in default context
    PGServer *loaded = [self loadedServerWithName:server.daemonName forRootUser:server.daemonForAllUsers];
    
    if (!loaded) {
        
        // Internal server - check if loaded in other context
        if (!server.external) {
            loaded = [self loadedServerWithName:server.daemonName forRootUser:!server.daemonForAllUsers];
    
        // External server - may have been detected using pid
        } else if (server.pid) {
            loaded = [self runningServerWithPid:server.pid];
        }
    }

    PGServerStatus prevStatus = server.status;
    
    // Not loaded
    if (!loaded) {
        server.pid = 0;
        server.status = PGServerStopped;
        if (server.status != prevStatus) server.error = nil;
        
    // Check settings match what we expect
    } else {
        server.pid = loaded.pid;
        server.status = loaded.status;
        
        // Validate Bin Directory
        if (NonBlank(loaded.settings.binDirectory) && !EqualPaths(loaded.settings.binDirectory, server.settings.binDirectory)) {
            server.error = @"Running with different bin directory!";
        
        // Validate Data Directory
        } else if (NonBlank(loaded.settings.dataDirectory) && !EqualPaths(loaded.settings.dataDirectory, server.settings.dataDirectory)) {
            server.error = @"Running with different data directory!";
        
        // Validate Port
        } else if (NonBlank(loaded.settings.port) && ![loaded.settings.port isEqualToString:server.settings.port]) {
            server.error = [NSString stringWithFormat:@"Running on port %@!", loaded.settings.port];
        
        // Validate Username
        } else if (NonBlank(loaded.settings.username) && !EqualUsernames(loaded.settings.username, server.settings.username)) {
            server.error = [NSString stringWithFormat:@"Running as user %@", loaded.settings.username];
            
        // No problems
        } else {
            if (server.status != prevStatus) server.error = nil;
        }
    }
}

- (void)populateSettings:(PGServerSettings *)settings fromProgramArgs:(NSArray *)args
{
    if (!settings || args.count == 0) return;
    
    // Executable
    NSString *executablePath = ToString(args[0]);
    NSString *executable = [executablePath lastPathComponent];
    
    // Not PostgreSQL
    if (!([executable isEqualToString:@"postgres"] ||
          [executable isEqualToString:@"pg_ctl"] ||
          [executable isEqualToString:@"postmaster"])
        ) return;
    
    // Bin directory
    settings.binDirectory = [executablePath stringByDeletingLastPathComponent];
    
    // Remaining args
    NSString *argType = nil;
    for (NSInteger i = 1; i < args.count; i++) {
        NSString *arg = TrimToNil(ToString(args[i]));
        if (!arg) continue;
        if ([arg hasPrefix:@"-"]) {
            if (arg.length == 1) { // Arg is just '-'
                argType = nil;
                continue;
            }
            argType = [arg substringWithRange:NSMakeRange(0,2)];
            arg = TrimToNil([arg substringFromIndex:2]);
            if (!arg) continue;
            
        } else if (!argType) {
            continue;
        }
        
        if ([argType isEqualToString:@"-D"]) {
            settings.dataDirectory = arg;
        } else if ([argType isEqualToString:@"-r"]) {
            settings.logFile = arg;
        } else if ([argType isEqualToString:@"-p"]) {
            settings.port = arg;
        }
        
        argType = nil;
    }
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

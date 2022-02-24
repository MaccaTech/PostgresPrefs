//
//  PGServerController.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 7/7/15.
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

#import "PGServerController.h"

#pragma mark - Constants / Functions

NSString *const PGServerCheckStatusName = @"Check Status";
NSString *const PGServerStartName       = @"Start";
NSString *const PGServerStopName        = @"Stop";
NSString *const PGServerCreateName      = @"Create";
NSString *const PGServerDeleteName      = @"Delete";

NSString *const PGServerCheckStatusVerb = @"check PostgreSQL status";
NSString *const PGServerStartVerb       = @"start PostgreSQL";
NSString *const PGServerStopVerb        = @"stop PostgreSQL";
NSString *const PGServerCreateVerb      = @"add PostgreSQL start script";
NSString *const PGServerDeleteVerb      = @"delete PostgresQL start script";

static inline BOOL
EqualPaths(NSString *path1, NSString *path2)
{
    path1 = TrimToNil(path1);
    path2 = TrimToNil(path2);
    if (!path1 && !path2) return YES;
    
    return [[path1 stringByStandardizingPath] isEqualToString:[path2 stringByStandardizingPath]];
}

static inline BOOL
EqualUsernames(NSString *user1, NSString *user2)
{
    user1 = TrimToNil(user1);
    user2 = TrimToNil(user2);
    if ([user1 isEqualToString:NSUserName()]) user1 = nil;
    if ([user2 isEqualToString:NSUserName()]) user2 = nil;
    
    if (!user1 && !user2) return YES;
    return [user1 isEqualToString:user2];
}

@interface NSDictionary (Filter)
/// Returns a filtered copy of this dictionary, using the block to decide which keys to include
- (NSDictionary *)dictionaryByFilteringUsingBlock:(BOOL(^)(id key, id value))block;
@end

@implementation NSDictionary (Filter)
- (NSDictionary *)dictionaryByFilteringUsingBlock:(BOOL (^)(id, id))block
{
    NSArray *keysToKeep = [self keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return block(key, obj);
    }].allObjects;
    
    if (keysToKeep.count == 0) return @{};
    return [NSDictionary dictionaryWithObjects:[self objectsForKeys:keysToKeep notFoundMarker:[NSNull null]] forKeys:keysToKeep];
}
@end



#pragma mark - Interfaces

@interface PGServerResult : NSObject
@property (nonatomic, readonly) PGServerStatus status;
@property (nonatomic, strong, readonly) NSString *error;
@property (nonatomic, readonly) PGServerAction errorAction;
- (instancetype)initWithServer:(PGServer *)server;
- (instancetype)initWithStatus:(PGServerStatus)status error:(NSString *)error errorAction:(PGServerAction)errorAction;
+ (instancetype)result:(PGServer *)server;
@end

@interface PGServerController ()

/**
 * Called before running the action. Opportunity to abort action, e.g. if validation fails.
 */
- (BOOL)shouldRunAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult error:(NSString **)error;

/**
 * Called after running the action if authorization failed
 */
- (void)didFailAuthForAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult auth:(PGAuth *)auth error:(NSString *)error;

/**
 * Called after running the action if an error occurred
 */
- (void)didFailAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult error:(NSString *)error;

/**
 * Called after running the action
 */
- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult;

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



#pragma mark - PGServerResult

@implementation PGServerResult
- (instancetype)initWithServer:(PGServer *)server
{
    return [self initWithStatus:server.status error:server.error errorAction:server.errorDomain];
}
- (instancetype)initWithStatus:(PGServerStatus)status error:(NSString *)error errorAction:(PGServerAction)errorAction
{
    self = [super init];
    if (self) {
        _status = status;
        _error = error;
        _errorAction = errorAction;
    }
    return self;
}
- (NSString *)description
{
    if (!_error) {
        return NSStringFromPGServerStatus(_status);
    } else {
        return [NSString stringWithFormat:@"%@ %@: %@", NSStringFromPGServerStatus(_status), NSStringFromPGServerAction(_errorAction), _error];
    }
}
+ (instancetype)result:(PGServer *)server { return [[PGServerResult alloc] initWithServer:server]; }
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

- (void)runAction:(PGServerAction)action server:(PGServer *)server auth:(PGAuth *)auth
{
    [self runAction:action server:server auth:auth succeeded:nil failed:nil];
}

- (void)runAction:(PGServerAction)action server:(PGServer *)server auth:(PGAuth *)auth succeeded:(void (^)(void))succeeded failed:(void (^)(NSString *error))failed
{
    BackgroundThread(^{
        [self runActionAndWait:action server:server auth:auth succeeded:succeeded failed:failed];
    });
}

- (void)runActionAndWait:(PGServerAction)action server:(PGServer *)server auth:(PGAuth *)auth succeeded:(void (^)(void))succeeded failed:(void (^)(NSString *error))failed
{
    // Abort quickly
    if (!server) return;
    if (server.processing && action == PGServerCheckStatus) return;
    
    // One action at a time for a server.
    // Note: thread blocks holding synchronized lock until done
    @synchronized(server) {
    
        NSString *error = nil;
        
        // Cache the existing status, because may need to revert to it if errors
        PGServerResult *previousResult = [PGServerResult result:server];
            
        // Validate server settings
        if ([self shouldRunAction:action server:server previousResult:previousResult error:&error]) {
        
            // For some actions, don't show a spinning wheel,
            // and don't remove the existing error until finished
            if (action != PGServerCheckStatus) {
                server.error = nil;
                server.errorDomain = action;
            }
            if (! (action == PGServerCheckStatus ||
                   action == PGServerCreate) ) {
                server.processing = YES;
            }

            // Notify delegate
            MainThread(^{
                [self.delegate server:server willRunAction:action];
            });
            
            // Execute
            switch (action) {
                    
                case PGServerCheckStatus:
                    [self checkStatusForServer:server];
                    break;
                    
                case PGServerStop:
                    [self stopServer:server all:!server.external auth:auth error:&error];
                    break;
                    
                case PGServerStart:
                    // Internal server
                    if (!server.external) {
                        // Validate
                        if (![self validateSettingsForServer:server auth:auth error:&error]) break;
                        // Unload
                        if (![self stopServer:server all:YES auth:auth error:&error]) break;
                        // Delete
                        if (![self deleteDaemonFileForServer:server all:YES auth:auth error:&error]) break;
                        // Create Daemon
                        if (![self createDaemonFileForServer:server auth:auth error:&error]) break;
                        // Create Log File
                        if (![self createLogFileForServer:server auth:auth error:&error]) break;
                        // Load
                        [self loadDaemonForServer:server auth:auth error:&error];
                        
                    // External server
                    } else {
                        // Unload
                        if (![self stopServer:server all:NO auth:auth error:&error]) break;
                        // Load
                        [self loadDaemonForServer:server auth:auth error:&error];
                    }
                    break;
                    
                case PGServerDelete:
                    if (![self stopServer:server all:!server.external auth:auth error:&error]) break;
                    [self deleteDaemonFileForServer:server all:!server.external auth:auth error:&error];
                    break;
                    
                case PGServerCreate:
                    if (server.external) {
                        error = @"Program error - cannot create external server";
                        break;
                    }
                    if (![self deleteDaemonFileForServer:server all:YES auth:auth error:&error]) break;
                    [self createDaemonFileForServer:server auth:auth error:&error];
                    break;
            }
            
            // Don't change spinning wheel for some actions
            if (! (action == PGServerCheckStatus ||
                   action == PGServerCreate)) {
                server.processing = NO;
            }
        }
        
        // Auth error
        if (auth.requested &&
            auth.status != errAuthorizationSuccess) {
            if (!error) { error = [NSString stringWithFormat:@"Authorization required to %@", NSStringFromPGServerAction(action).lowercaseString]; }
            [self didFailAuthForAction:action server:server previousResult:previousResult auth:auth error:error];
         
        // Error
        } else if (error) {
            [self didFailAction:action server:server previousResult:previousResult error:error];
            
        // Check result
        } else {
            [self didRunAction:action server:server previousResult:previousResult];
        }
        
        // Log
        if (IsLogging) {
            DLog(@"[%@] %@ : %@%@", server.name, NSStringFromPGServerAction(action), NSStringFromPGServerStatus(server.status), (server.error?[NSString stringWithFormat:@"\n\n[error] %@", server.error]:@""));
        }

        // Notify delegate - keep notifications ordered correctly
        // by scheduling on main while still holding synchronized lock.
        MainThreadAfterDelay(0, ^{
            if (NonBlank(error)) {
                if (failed) failed(error);
                else [self.delegate server:server didFailAction:action error:error];
            } else {
                if (succeeded) succeeded();
                else [self.delegate server:server didSucceedAction:action];
            }
            [self.delegate server:server didRunAction:action];
        });
        
    } // End synchronized
}

- (BOOL)validateSettingsForServer:(PGServer *)server auth:(PGAuth *)auth error:(NSString **)error
{
    PGServerSettings *settings = server.settings;
    [self validateServerSettings:settings];
    if (!settings.valid) {
        if (error) *error = @"Server settings are invalid";
        return NO;
    }
    
    PGUser *user = [PGUser userWithUsername:settings.username];
    
    // Username
    if (NonBlank(settings.username) && !user) {
        settings.invalidUsername = @"No such user";
    }
    
    // Bin directory
    if (![PGFile dirExists:settings.binDirectory user:user auth:auth error:error]) {
        settings.invalidBinDirectory = @"No such directory";
    }

    
    // Data directory
    if (![PGFile dirExists:settings.dataDirectory user:user auth:auth error:error]) {
        settings.invalidDataDirectory = @"No such directory";
    }
    
    // Log directory
    if (NonBlank(settings.logFile) && ![PGFile dirExists:[settings.logFile stringByDeletingLastPathComponent] user:user auth:auth error:error]) {
        settings.invalidLogFile = @"No such directory";
    }
    
    if (!settings.valid) {
        if (error) *error = @"Server settings are invalid";
        return NO;
    }
    return YES;
}

- (BOOL)stopServer:(PGServer *)server all:(BOOL)all auth:(PGAuth *)auth error:(NSString **)outerr
{
    // 'launchctl bootout' on Catalina returns an error message,
    // even though it succeeds. So error is not always reliable.
    // Only return error if process is definitely still running
    // at end of this method.
    if (outerr) { *outerr = nil; }
    NSString *error = nil;
    
    // Unload using launchctl
    [self unloadDaemonForServer:server all:all auth:auth error:&error];
    [NSThread sleepForTimeInterval:1.0];
    
    if (!server.pid) return YES;
    
    // Check stopped
    PGProcess *process = [PGProcess runningProcessWithPid:server.pid];
    if (!process) return YES;
    
    // Still running - kill
    [PGProcess kill:server.pid forRootUser:process.user.isOtherUser auth:auth error:&error];

    // Check stopped
    process = [PGProcess runningProcessWithPid:server.pid];
    if (!process) return YES;
    
    // Still running - error
    if (outerr) { *outerr = error; }
    return NO;
}
- (BOOL)unloadDaemonForServer:(PGServer *)server all:(BOOL)all auth:(PGAuth *)auth error:(NSString **)error
{
    // For authInfo popup
    auth.reason = @{
        PGAuthReasonAction: @"Stop PostgreSQL using",
        PGAuthReasonTarget: @"system launchd"
    };

    if (![PGLaunchd stopDaemonWithName:server.daemonName forRootUser:server.daemonFileOwner.isRootUser auth:auth error:error]) return NO;
    
    if (!all) return YES;
    
    if ([PGLaunchd loadedDaemonWithName:server.daemonName forRootUser:!server.daemonFileOwner.isRootUser]) {
        if (![PGLaunchd stopDaemonWithName:server.daemonName forRootUser:!server.daemonFileOwner.isRootUser auth:auth error:error]) return NO;
    }
    
    return YES;
}
- (BOOL)loadDaemonForServer:(PGServer *)server auth:(PGAuth *)auth error:(NSString **)outerr
{
    __block BOOL result = NO;
    __block NSString *error = nil;
    [PGFile temporaryFileWithExtension:@".plist" usingBlock:^(NSString *tempPath) {
        
        // Create temp plist file with "Disabled" property set to false
        result = [self createEnabledDaemonFileForServer:server path:tempPath auth:auth error:&error];
        if (!result) { return; }

        // For authInfo popup
        auth.reason = @{
            PGAuthReasonAction: @"Start PostgreSQL using",
            PGAuthReasonTarget: @"system launchd"
        };

        // Load
        result = [PGLaunchd startDaemonWithFile:tempPath forRootUser:server.daemonFileOwner.isRootUser auth:auth error:&error];
    }];
    if (outerr) { *outerr = error; }
    if (result) { [NSThread sleepForTimeInterval:1.0]; }
    return result;
}
- (BOOL)deleteDaemonFileForServer:(PGServer *)server all:(BOOL)all auth:(PGAuth *)auth error:(NSString **)error
{
    // For authInfo popup
    NSMutableDictionary *reason = [NSMutableDictionary dictionaryWithDictionary:@{
        PGAuthReasonAction: @"Remove PostgreSQL plist file from",
        PGAuthReasonTarget: [server.daemonFile stringByDeletingLastPathComponent]
    }];
    auth.reason = reason;
    
    // Note that delete returns YES if the file is already deleted
    if (![PGFile remove:server.daemonFile auth:auth error:error]) return NO;
    
    if (!all) return YES;
    
    reason[PGAuthReasonTarget] = [server.daemonFileForAllUsersAtBoot stringByDeletingLastPathComponent];
    if ([PGFile fileExists:server.daemonFileForAllUsersAtBoot]) {
        if (![PGFile remove:server.daemonFileForAllUsersAtBoot auth:auth error:error]) return NO;
    }
    reason[PGAuthReasonTarget] = [server.daemonFileForAllUsersAtLogin stringByDeletingLastPathComponent];
    if ([PGFile fileExists:server.daemonFileForAllUsersAtLogin]) {
        if (![PGFile remove:server.daemonFileForAllUsersAtLogin auth:auth error:error]) return NO;
    }
    reason[PGAuthReasonTarget] = [server.daemonFileForCurrentUserOnly stringByDeletingLastPathComponent];
    if ([PGFile fileExists:server.daemonFileForCurrentUserOnly]) {
        if (![PGFile remove:server.daemonFileForCurrentUserOnly auth:auth error:error]) return NO;
    }

    return YES;
}
- (BOOL)createDaemonFileForServer:(PGServer *)server auth:(PGAuth *)auth error:(NSString **)error
{
    // For authInfo popup
    auth.reason = @{
        PGAuthReasonAction: @"Create PostgreSQL plist file in",
        PGAuthReasonTarget: server.daemonFile.stringByDeletingLastPathComponent
    };

    NSDictionary *daemon = [self daemonFromServer:server];
    if (daemon.count == 0) return NO;
    
    return [PGFile createPlistFile:server.daemonFile contents:daemon user:server.daemonFileOwner auth:auth error:error];
}
- (BOOL)createEnabledDaemonFileForServer:(PGServer *)server path:(NSString *)path auth:(PGAuth *)auth error:(NSString **)error
{
    // For authInfo popup
    auth.reason = @{
        PGAuthReasonAction: @"Create PostgreSQL agent in",
        PGAuthReasonTarget: @"temporary directory"
    };

    NSDictionary *daemon = [self daemonFromServer:server];
    if (daemon.count == 0) return NO;
    
    // Remove disabled setting
    daemon = [daemon dictionaryByFilteringUsingBlock:^BOOL(id key, id value) {
        return ![key isEqualToString:@"Disabled"];
    }];
    
    return [PGFile createPlistFile:path contents:daemon user:server.daemonFileOwner auth:auth error:error];
}
- (BOOL)createLogFileForServer:(PGServer *)server auth:(PGAuth *)auth error:(NSString **)error
{
    // For authInfo popup
    auth.reason = @{
        PGAuthReasonAction: @"Create PostgreSQL log file in",
        PGAuthReasonTarget: server.daemonLog.stringByDeletingLastPathComponent
    };

    // Create Log Dir
    if (![PGFile createDir:[server.daemonLog stringByDeletingLastPathComponent] user:(server.daemonForAllUsers ? PGUser.root : nil) auth:auth error:error]) return NO;
    
    // Create Log File
    if (![PGFile createFile:server.daemonLog contents:nil user:[PGUser userWithUsername:server.settings.username] auth:auth error:error]) return NO;
    
    return YES;
}

- (PGServer *)runningServerWithPid:(NSInteger)pid
{
    return [self serverFromProcess:[PGProcess runningProcessWithPid:pid]];
}

- (PGServer *)loadedServerWithName:(NSString *)name forRootUser:(BOOL)root
{
    NSDictionary *daemon = [PGLaunchd loadedDaemonWithName:name forRootUser:root];
    return [self serverFromLoadedDaemon:daemon forRootUser:root];
}

- (PGServer *)serverFromProcess:(PGProcess *)process
{
    if (!process) return nil;
    
    NSArray<NSString *> *programArgs = [self programArgsFromCommand:process.command];
    
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
    if (![PGFile fileExists:file]) return nil;
    
    NSDictionary *daemon = [[NSDictionary alloc] initWithContentsOfFile:[file stringByExpandingTildeInPath]];
    if (IsLogging) { if (daemon.count > 0) { DLog(@"%@\n%@", file, daemon); } }
    
    PGServer *result = [self serverFromDaemon:daemon];
    
    // Set domain from filename if not in daemon's contents
    if (result && !NonBlank(result.domain)) {
        NSString *daemonName = file.lastPathComponent.stringByDeletingPathExtension;
        NSString *domain = nil;
        [self partsBySplittingFullName:daemonName user:nil name:nil domain:&domain];
        result.domain = domain;
    }
    
    return result;
}

- (PGServer *)serverFromLoadedDaemon:(NSDictionary *)daemon forRootUser:(BOOL)root
{
    if (IsLogging) { if (daemon.count > 0) { DLog(@"%@ launchd\n%@", (root ? @"System" : @"User"), daemon); } }

    PGServer *result = [self serverFromDaemon:daemon];
    result.daemonLoadedForAllUsers = root;
    
    // A server with the same Label could potentially be loaded in BOTH the root and user contexts.
    // For Internal servers, these are treated as the same server.
    // For External servers, these must be treated as different, so root@ is prepended to name.
    if (result.external && root) result.name = [NSString stringWithFormat:@"root@%@", result.name];
    
    return result;
}

- (PGServer *)serverFromDaemon:(NSDictionary *)daemon
{
    if (daemon.count == 0) return nil;
    
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
             @"Label": (server.daemonName ?: [NSNull null]),
             @"UserName": (server.daemonForAllUsers ? (server.settings.username ?: NSUserName()) : [NSNull null]),
             @"ProgramArguments": (programArgs ?: [NSNull null]),
             @"WorkingDirectory": (dataDir ?: [NSNull null]),
             @"StandardOutPath": (daemonLog ?: [NSNull null]),
             @"StandardErrorPath": (daemonLog ?: [NSNull null]),
             @"RunAtLoad": @YES,
             @"KeepAlive": @{ @"SuccessfulExit": @NO },
             @"Disabled": (server.settings.startup == PGServerStartupManual ? @YES : @NO)
    } dictionaryByFilteringUsingBlock:^BOOL (id key, id value) {
        return value != [NSNull null];
    }];
}

- (NSDictionary *)propertiesFromServer:(PGServer *)server
{
    return server.properties;
}

- (PGServer *)serverFromProperties:(NSDictionary *)properties name:(NSString *)name domain:(NSString *)domain
{
    if (![PGServer hasAllKeys:properties]) return nil;
    
    PGServer *server = [[PGServer alloc] initWithName:name domain:domain];
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
    server.external = ![server.domain isEqualToString:PGPrefsAppID];
    
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
    
    if (NonBlank(settings.username)) {
        if ([settings.username rangeOfCharacterFromSet:invalidUsernameCharacterSet].location != NSNotFound) {
            settings.invalidUsername = @"Invalid characters";
        } else if (![PGUser userWithUsername:settings.username]) {
            settings.invalidUsername = @"User not found";
        }
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

- (BOOL)shouldRunAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult error:(NSString *__autoreleasing *)error
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

- (void)didFailAuthForAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult auth:(PGAuth *)auth error:(NSString *)error
{
    switch (action) {
        case PGServerStart:  // Fall through
        case PGServerStop:   // Fall through
        case PGServerCreate: // Fall through
        case PGServerDelete: // Fall through
            server.status = previousResult.status;
            if (auth.status != errAuthorizationCanceled) {
                server.error = error;
                server.errorDomain = action;
            }
            break;
        case PGServerCheckStatus:
            DLog(@"Failed to check status for %@\n%@", server.name, error);
            break;
    }
}

- (void)didFailAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult error:(NSString *)error
{
    switch (action) {
        case PGServerStart:  // Fall through
        case PGServerStop:   // Fall through
        case PGServerCreate: // Fall through
        case PGServerDelete: // Fall through
            server.status = previousResult.status;
            server.error = error;
            server.errorDomain = action;
            break;
        case PGServerCheckStatus:
            DLog(@"Failed to check status for %@\n%@", server.name, error);
            break;
    }
}

- (void)didRunAction:(PGServerAction)action server:(PGServer *)server previousResult:(PGServerResult *)previousResult
{
    switch (action) {
        // Will always call check status afterwards to confirm if really did start
        case PGServerStart: server.status = PGServerStarting; break;
        case PGServerStop: server.status = PGServerStopped; break;
        case PGServerDelete: server.status = PGServerStopped; break;
        case PGServerCreate: if (server.status == PGServerUpdating) server.status = previousResult.status; break;
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
        server.daemonLoadedForAllUsers = loaded.daemonLoadedForAllUsers;
        
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

- (NSArray<NSString *> *)programArgsFromCommand:(NSString *)command
{
    NSArray<NSString *> *args = [command componentsSeparatedByString:@" "];
    if (args.count == 1) { return args; }
    
    // Need to allow for spaces in paths
    // E.g. ~/Library/Application Support/Postgres
    // This is incorrectly split into 2 separate args
    //
    // If a component doesn't look like an option (starting with a hyphen),
    // then assume it's a path and join it to the previous component.
    NSMutableArray<NSString *> *programArgs = [NSMutableArray arrayWithCapacity:args.count];
    NSMutableString *buffer = [NSMutableString string];
    for (NSString *arg in args) {
        
        BOOL isShortOption = [arg hasPrefix:@"-"] &&
            arg.length > 1 &&
            [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[arg characterAtIndex:1]];
        BOOL isLongOption = !isShortOption &&
            [arg hasPrefix:@"--"] &&
            arg.length > 2 &&
            [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[arg characterAtIndex:2]];
        
        // New option, flush buffer containing previous arg
        if (isShortOption || isLongOption) {
            if (buffer.length > 0) {
                [programArgs addObject:[NSString stringWithString:buffer]];
                [buffer deleteCharactersInRange:NSMakeRange(0,buffer.length)];
            }
        }
        
        // Short option, arg is complete
        if (isShortOption) {
            [programArgs addObject:arg];
            
        // Anything else, arg may need to join to next component,
        // so add to buffer
        } else {
            if (buffer.length > 0) { [buffer appendString:@" "]; }
            [buffer appendString:arg];
        }
    }
    
    // Final flush buffer
    if (buffer.length > 0) {
        [programArgs addObject:[NSString stringWithString:buffer]];
    }

    return [NSArray arrayWithArray:programArgs];
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
    else result = [NSString stringWithFormat:@"%@.%@", domain, name];
    return user && result ? [NSString stringWithFormat:@"%@@%@", user, result] : result;
}

@end

//
//  PostgrePrefsDelegate.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 18/12/11.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGPrefsController.h"

#pragma mark - Inlines

// Get the next object in the array
CG_INLINE id
ObjectAfter(id object, NSArray *array)
{
    if (array.count < 2) return nil;
    if (object == array.lastObject) return nil;
    
    NSUInteger index = [array indexOfObject:object];
    if (index == NSNotFound) return nil;
    
    return index < array.count-1 ? array[index+1] : nil;
}
// Get the preceeding object in the array
CG_INLINE id
ObjectBefore(id object, NSArray *array)
{
    if (array.count < 2) return nil;
    if (object == array.firstObject) return nil;
    
    NSUInteger index = [array indexOfObject:object];
    if (index == NSNotFound) return nil;
    
    return index == 0 ? nil : array[index-1];
}



#pragma mark - Interfaces

@interface PGPrefsController()

@property (nonatomic, strong, readwrite) PGServerController *serverController;
@property (nonatomic, strong, readwrite) PGSearchController *searchController;
@property (nonatomic, strong, readwrite) PGServerDataStore *dataStore;
@property (nonatomic, strong, readwrite) PGServer *server;
@property (nonatomic, strong, readwrite) NSArray *servers;
@property (nonatomic, readwrite) AuthorizationRef authorization;
/// Used to start/stop all monitor threads. To stop all threads, set this key to nil. When a monitor thread runs, it compares its key to this one. If the keys are different, the monitor thread stops running.
@property (nonatomic, strong) id serversMonitorKey;

/**
 * If already authorized, returns the stored authorization. Otherwise, triggers user to authorize.
 *
 * @return nil if user cancelled
 */
- (AuthorizationRef)authorize;
/**
 * Checks settings and marks invalid as appropriate
 */
- (void)validateSettings:(PGServerSettings *)settings;
/**
 * Populates transient properties in server, and validates server settings.
 */
- (void)initializeServer:(PGServer *)server;

@end



#pragma mark - PGPrefsController

@implementation PGPrefsController

#pragma mark Lifecycle

- (id)init
{
    return [self initWithViewController:nil];
}
- (id)initWithViewController:(id<PGPrefsViewController>)viewController
{
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.searchController = [[PGSearchController alloc] initWithDelegate:self];
        self.serverController = [[PGServerController alloc] initWithDelegate:self];
        self.dataStore = [[PGServerDataStore alloc] init];
        self.authorization = NULL;
    }
    return self;
}
- (void)viewDidLoad
{
    DLog(@"Loaded");
    
    [self.viewController prefsController:self didChangeServers:nil];
    [self.viewController prefsController:self didChangeSelectedServer:nil];
    
    // Load servers from plist
    [self.dataStore loadServers];
    self.servers = self.dataStore.servers;
    self.server = self.servers.firstObject;
    
    // Validate servers
    for (PGServer *server in self.servers) [self initializeServer:server];
    
    [self.viewController prefsController:self didChangeServers:self.servers];
    [self.viewController prefsController:self didChangeSelectedServer:self.server];
}
- (void)viewWillAppear
{
    // Do nothing
}
- (void)viewDidAppear
{
    // Start periodic server monitoring
    [self startMonitoringServers];
}
- (void)viewWillDisappear
{
    // Ensure saved preferences are written to disk
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.viewController deauthorize];
    
    // Stop periodic server monitoring
    [self stopMonitoringServers];
}
- (void)viewDidDisappear
{
    DLog(@"didUnselect");
}
- (void)viewDidAuthorize:(AuthorizationRef)authorization
{
    self.authorization = authorization;
    if (authorization == NULL) return;
    
    // Refresh display of protected servers
    for (PGServer *server in self.servers) {
        if (!server.needsAuthorization) continue;
        server.error = nil;
        [self.viewController prefsController:self didChangeServerStatus:server];
        
        [self checkStatus:server];
    }
}
//
// DidDauthorize method will be called in any of following situations:
// 1. User clicked to close lock
// 2. User clicked show all
// 3. Sometimes called after PrefsDidLoad! <-- IMPORTANT
//
- (void)viewDidDeauthorize
{
    DLog(@"Deauthorized");
    
    self.authorization = NULL;
    
    // Refresh display of protected servers
    for (PGServer *server in self.servers) {
        if (!server.needsAuthorization) continue;
        server.error = nil;
        [self.viewController prefsController:self didChangeServerStatus:server];
    }
}
- (AuthorizationRights *)authorizationRights
{
    return self.serverController.authorizationRights;
}



#pragma mark Servers

- (void)userDidSelectServer:(PGServer *)server
{
    self.server = server;
    
    [self.viewController prefsController:self didChangeSelectedServer:self.server];
}
- (void)userDidAddServer
{
    PGServer *server = [self.dataStore addServer];
    if (!server) return;
    
    // Get the new servers list after add
    self.servers = self.dataStore.servers;
    
    // Select the new server
    self.server = server;
    
    // Initialize the new server
    [self initializeServer:server];
    
    // Start monitoring
    [self startMonitoringServer:server];
    
    [self.viewController prefsController:self didChangeServers:self.servers];
    [self.viewController prefsController:self didChangeSelectedServer:self.server];
    
    // Start editing
    [self userWillEditSettings];
}
- (void)userDidDeleteServer
{
    if (!self.server) return;
    
    AuthorizationRef authorization = [self authorize];
    if (authorization == NULL) return;
    
    // Run script
    PGServer *server = self.server;
    BackgroundThread(^{
        [self.serverController runAction:PGServerDelete server:server authorization:authorization succeeded:^{
            
            MainThread(^{
                // Calculate which server to select after delete
                PGServer *nextServer = ObjectAfter(server, self.servers);
                if (!nextServer) nextServer = ObjectBefore(server, self.servers);
                
                // Delete the server
                [self.dataStore removeServer:server];
                
                // Get the new servers list after delete
                self.servers = self.dataStore.servers;
                
                // Select the next server
                self.server = nextServer;
                
                [self.viewController prefsController:self didChangeServers:self.servers];
                [self.viewController prefsController:self didChangeSelectedServer:self.server];
            });
        } failed:nil];
    });
}
- (BOOL)userCanRenameServer:(NSString *)name
{
    return [self.dataStore serverWithName:name] == nil;
}
- (void)userDidRenameServer:(NSString *)name
{
    AuthorizationRef authorization = [self authorize];
    if (authorization == NULL) return;
    
    PGServer *server = self.server;
    PGServerAction finalAction = self.server.status == PGServerStarted ? PGServerStart : PGServerCreate;
    BackgroundThread(^{
        // First stop and delete the existing server
        [self.serverController runAction:PGServerDelete server:server authorization:authorization succeeded:^{
            
            // Commit the user's new settings
            BOOL succeeded = [self.dataStore setName:name forServer:server];
            if (!succeeded) return;
            
            // Re-initialize the modified server
            [self initializeServer:server];
            
            MainThread(^{
                [self.viewController prefsController:self didChangeServers:self.servers];
            });
            
            // Create and start (if needed) the new server
            [self.serverController runAction:finalAction server:server authorization:authorization succeeded:^{
                
                [self.viewController prefsController:self didApplyServerSettings:server];
                
                [self checkStatus:server];
            } failed:nil];
        } failed:nil];
    });
}
- (void)userDidCancelRenameServer
{
    // Do nothing
}



#pragma mark Start/Stop

- (void)userDidStartStopServer
{
    if (!self.server) return;
    
    // Determine action based on current status
    PGServerAction action;
    switch (self.server.status) {
        case PGServerStarted: // Fall through
        case PGServerRetrying: action = PGServerStop; break;
        case PGServerStopped: action = PGServerStart; break;
        default: action = PGServerCheckStatus;
    }
    
    // Start/Stop
    if (action == PGServerStart || action == PGServerStop) {
        
        AuthorizationRef authorization = [self authorize];
        if (authorization == NULL) return;
        
        PGServer *server = self.server;
        BackgroundThread(^{ [self.serverController runAction:action server:server authorization:authorization succeeded:^{
            [self checkStatus:server];
        } failed:nil]; });
        
    // Check Status
    } else {
        [self checkStatus:self.server];
    }
}



#pragma mark Settings

- (void)userDidSelectSearchServer:(PGServer *)server
{
    PGServerSettings *dirtySettings = [self dirty:self.server];
    dirtySettings.properties = server.settings.properties;
    
    [self.viewController prefsController:self didRevertServerSettings:self.server];
}
- (void)userWillEditSettings
{
    [self.searchController startFindServers];
    
    [self.viewController prefsController:self willEditServerSettings:self.server];
}
- (void)userDidChangeServerStartup:(NSString *)startup
{
    // Revert startup in GUI if user cancelled authorization
    AuthorizationRef authorization = [self authorize];
    if (authorization == NULL) {
        [self.viewController prefsController:self didRevertServerStartup:self.server];
        return;
    }
    
    // Update server
    PGServerStartup oldStartup = self.server.settings.startup;
    PGServerStartup newStartup = ToServerStartup(startup);
    PGServerSettings *dirtySettings = [self dirty:self.server];
    dirtySettings.startup = newStartup;
    
    // Commit the user's new settings
    BOOL saved = [self.dataStore saveServer:self.server];
    if (!saved) {
        dirtySettings.startup = oldStartup;
        [self.viewController prefsController:self didRevertServerStartup:self.server];
        return;
    }
    
    // Re-initialize the modified server
    [self initializeServer:self.server];
    
    // Run script
    PGServerAction action = self.server.status == PGServerStarted || self.server.status == PGServerRetrying ? PGServerStart : PGServerCreate;
    PGServer *server = self.server;
    BackgroundThread(^{
        [self.serverController runAction:action server:server authorization:authorization succeeded:^{
            [self checkStatus:server];
        } failed:nil];
    });
}
- (void)userDidChangeSetting:(NSString *)setting value:(NSString *)value
{
    PGServerSettings *dirtySettings = [self dirty:self.server];
    
    if ([setting isEqualToString:PGServerUsernameKey]) {
        dirtySettings.username = value;
    } else if ([setting isEqualToString:PGServerBinDirectoryKey]) {
        dirtySettings.binDirectory = value;
    } else if ([setting isEqualToString:PGServerDataDirectoryKey]) {
        dirtySettings.dataDirectory = value;
    } else if ([setting isEqualToString:PGServerLogFileKey]) {
        dirtySettings.logFile = value;
    } else if ([setting isEqualToString:PGServerPortKey]) {
        dirtySettings.port = value;
    } else return;

    [self validateSettings:dirtySettings];
    [self.viewController prefsController:self didDirtyServerSettings:self.server];
}
- (void)userDidRevertSettings
{
    self.server.dirtySettings = nil;

    [self.viewController prefsController:self didRevertServerSettings:self.server];
}
- (void)userDidApplySettings
{
    AuthorizationRef authorization = [self authorize];
    if (authorization == NULL) return;
    
    PGServer *server = self.server;
    PGServerAction finalAction = self.server.status == PGServerStarted || self.server.status == PGServerRetrying ? PGServerStart : PGServerCreate;
    BackgroundThread(^{
        // First stop and delete the existing server
        [self.serverController runAction:PGServerDelete server:self.server authorization:authorization succeeded:^{

            // Commit the user's new settings
            BOOL saved = [self.dataStore saveServer:server];
            if (!saved) return;
            
            // Re-initialize the modified server
            [self initializeServer:server];
            
            // Create and start (if needed) the new server
            [self.serverController runAction:finalAction server:server authorization:authorization succeeded:^{
                
                [self checkStatus:server];
                
                [self.viewController prefsController:self didApplyServerSettings:server];
            } failed:nil];
        } failed:nil];
    });
}
- (void)userDidCancelSettings
{
    self.server.dirtySettings = nil;
    
    [self.viewController prefsController:self didRevertServerSettings:self.server];
}



#pragma mark Log

- (void)userDidViewLog
{
    if (!self.server.logExists) return;

    NSString *source = [NSString stringWithFormat:@""
                        "tell application \"Console\"\n"
                        "activate\n"
                        "open \"%@\"\n"
                        "end tell", self.server.log];
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:nil];
}



#pragma mark PGServerDelegate

- (void)postgreServer:(PGServer *)server willRunAction:(PGServerAction)action
{
    MainThread(^{
        [self.viewController prefsController:self didChangeServerStatus:server];
    });
}
- (void)postgreServer:(PGServer *)server didSucceedAction:(PGServerAction)action
{
    MainThread(^{
        [self.viewController prefsController:self didChangeServerStatus:server];
    });
}
- (void)postgreServer:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error
{
    MainThread(^{
        [self.viewController prefsController:self didChangeServerStatus:server];
    });
}
- (void)postgreServer:(PGServer *)server didRunAction:(PGServerAction)action
{
    // Do nothing
}



#pragma mark PGSearchDelegate

- (void)didFindMoreServers:(PGSearchController *)search
{
    [self.viewController prefsController:self didChangeSearchServers:search.servers];
}



#pragma mark Private

- (AuthorizationRef)authorize
{
    if (self.authorization) return self.authorization;
    else return [self.viewController authorize];
}

- (void)validateSettings:(PGServerSettings *)settings
{
    [settings setValid];
    settings.invalidBinDirectory = !NonBlank(settings.binDirectory);
    settings.invalidDataDirectory = !NonBlank(settings.dataDirectory);
}

- (PGServerSettings *)dirty:(PGServer *)server
{
    return server.dirtySettings ?: (server.dirtySettings = [[PGServerSettings alloc] initWithSettings:server.settings]);
}

- (void)initializeServer:(PGServer *)server
{
    [self validateSettings:server.settings];
    
    // Generate log file path
    if (NonBlank(server.name)) {
        NSString *logFile = [NSString stringWithFormat:@"/Library/Logs/PostgreSQL/%@.%@.log", PGPrefsAppID, server.name];
        if (!server.needsAuthorization) logFile = [NSHomeDirectory() stringByAppendingPathComponent:logFile];
        server.log = logFile;
    }
}

- (void)checkStatus:(PGServer *)server
{
    if (!server) return;
    
    if (server.needsAuthorization) {
        AuthorizationRef authorization = self.authorization;
        if (authorization == NULL) {
            [self.viewController prefsController:self didChangeServerStatus:server];
            return;
        }
        
        BackgroundThread(^{ [self.serverController runAction:PGServerCheckStatus server:server authorization:authorization]; });
    } else {
        BackgroundThread(^{ [self.serverController runAction:PGServerCheckStatus server:server authorization:nil]; });
    }
}

- (void)startMonitoringServers
{
    self.serversMonitorKey = [NSDate date];
    for (PGServer *server in self.servers) [self startMonitoringServer:server];
}
- (void)startMonitoringServer:(PGServer *)server
{
    BackgroundThread(^{ [self poll:server key:self.serversMonitorKey]; });
}
- (void)poll:(PGServer *)server key:(id)key
{
    if (!key) return;

    NSTimeInterval secondsBetweenStatusUpdates = 5;
    
    // Ensure not stopped
    if (key != self.serversMonitorKey) return;
    
    // Ensure server not deleted
    __block BOOL serverExists = YES;
    MainThread(^{ serverExists = [self.servers containsObject:server]; });
    if (!serverExists) return;
    
    // Ensure server not already processing
    if (!server.processing) {
        
        // Run check status command
        AuthorizationRef authorization = self.authorization;
        if (!server.needsAuthorization || authorization != NULL) [self.serverController runAction:PGServerQuickStatus server:server authorization:authorization];
    }
    
    // Ensure not stopped
    if (key != self.serversMonitorKey) return;
    
    // Global disable auto-monitoring
    if (!PGPrefsMonitorServersEnabled) return;
    
    // Schedule re-run
    BackgroundThreadAfterDelay(^{ [self poll:server key:key]; }, secondsBetweenStatusUpdates);
}
- (void)stopMonitoringServers
{
    self.serversMonitorKey = nil;
}

@end

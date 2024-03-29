//
//  PGPrefsController.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 18/12/11.
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

#import "PGPrefsController.h"

#pragma mark - Utils

@interface NSArray (BeforeAfter)
/// Get the next object in the array
- (id)objectAfter:(id)object;
/// Get the preceeding object in the array
- (id)objectBefore:(id)object;
@end

@implementation NSArray (BeforeAfter)
- (id)objectAfter:(id)object
{
    if (self.count < 2) return nil;
    if (object == self.lastObject) return nil;
    
    NSUInteger index = [self indexOfObject:object];
    if (index == NSNotFound) return nil;
    
    return index < self.count-1 ? self[index+1] : nil;
}
- (id)objectBefore:(id)object
{
    if (self.count < 2) return nil;
    if (object == self.firstObject) return nil;
    
    NSUInteger index = [self indexOfObject:object];
    if (index == NSNotFound) return nil;
    
    return index == 0 ? nil : self[index-1];
}
@end


#pragma mark - Thread Control

@class PGThreadController;

/// Allows cancelling running threads.
@interface PGThreadManager : NSObject
/// Use 'enabled' rather than 'cancelled' as the property name, since checking 'enabled'
/// on a nil object will yield the correct result, but checking 'cancelled' will not.
@property (nonatomic, readonly) BOOL enabled;
- (void)cancel;
- (PGThreadController *)makeController;
@end

/// Each running thread has its own controller. Benefit is that each controller holds a weak
/// reference to the manager, allowing the manager to dealloc and cancel itself.
@interface PGThreadController : NSObject
@property (nonatomic, weak, readonly) PGThreadManager *manager;
- (instancetype)initWithManager:(PGThreadManager *)manager;
@end

@implementation PGThreadManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        _enabled = YES;
    }
    return self;
}
- (void)dealloc { [self cancel]; }
- (void)cancel { _enabled = NO; }
- (PGThreadController *)makeController { return [[PGThreadController alloc] initWithManager:self]; }
@end

@implementation PGThreadController
- (instancetype)initWithManager:(PGThreadManager *)manager
{
    self = [super init];
    if (self) {
        _manager = manager;
    }
    return self;
}
@end



#pragma mark - Interfaces

@interface PGPrefsController () <PGAuthDelegate>

@property (nonatomic, strong, readwrite) PGServerController *serverController;
@property (nonatomic, strong, readwrite) PGSearchController *searchController;
@property (nonatomic, strong, readwrite) PGServerDataStore *dataStore;
@property (nonatomic, strong, readwrite) PGServer *server;
@property (nonatomic, strong, readwrite) NSArray *servers;
@property (nonatomic, readwrite) AuthorizationRef authorization;
/// Used to start/stop all monitor threads. The monitor threads take a reference to this manager
/// when they start running, and periodically check if it is still enabled. If not, they exit.
@property (nonatomic, strong) PGThreadManager *serversMonitorManager;

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
        self.serverController = [[PGServerController alloc] init];
        self.searchController = [[PGSearchController alloc] init];
        self.dataStore = [[PGServerDataStore alloc] init];
        self.serverController.delegate = self;
        self.searchController.delegate = self;
        self.searchController.serverController = self.serverController;
        self.dataStore.serverController = self.serverController;
        self.authorization = nil;
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
    
    self.authorization = nil;
}
- (PGRights *)rights
{
    return self.serverController.rights;
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
    
    // Internal
    if (!self.server.external) {
        [self deleteServerAndDeleteFile:YES];
    
    // External
    } else {
        // Daemon file exists
        if (self.server.daemonFileExists) {
            [self.viewController prefsController:self willConfirmDeleteServer:self.server];
            
        // Daemon file not found
        } else {
            [self deleteServerAndDeleteFile:NO];
        }
    }
}
- (BOOL)userCanRenameServer:(NSString *)name
{
    return [self.dataStore serverWithName:name] == nil;
}
- (void)userDidRenameServer:(NSString *)name
{
    PGServer *server = self.server;
    if (!server) return;

    PGAuth *auth = [[PGAuth alloc] initWithDelegate:self];
    PGServerAction finalAction = server.started ? PGServerStart : PGServerCreate;
    
    // 1. Stop and delete the existing server
    [self.serverController runAction:PGServerDelete server:server auth:auth succeeded:^{
        
        // Backup existing
        NSString *oldName = server.name;
        NSString *newName = name;

        // Apply the change
        BOOL succeeded = [self.serverController setName:newName forServer:server];
        
        // Save
        if (succeeded) succeeded = [self.dataStore saveServer:server];
        
        // Save failed - restore backup
        if (!succeeded) {
            [self.serverController setName:oldName forServer:server];
            return;
        }
    
        // Get the new servers list after rename
        self.servers = self.dataStore.servers;
        
        [self.viewController prefsController:self didChangeServers:self.servers];
        
        // 2. Create and start (if needed) the new server
        [self.serverController runAction:finalAction server:server auth:auth succeeded:^{
            
            [self.viewController prefsController:self didApplyServerSettings:server];
            
            [self checkStatus:server];

        } failed:nil];
    } failed:nil];
}
- (void)userDidCancelRenameServer
{
    // Do nothing
}
- (void)userDidDuplicateServer
{
    if (!self.server) return;
    
    // Create the server and copy over the settings
    PGServer *server = [self.dataStore addServerWithName:self.server.shortName settings:self.server.settings];
    if (!server) return;
    
    // Get the new servers list after add
    self.servers = self.dataStore.servers;
    
    // Select the new server
    self.server = server;
    
    // Start monitoring
    [self startMonitoringServer:server];
    
    // Update view
    [self.viewController prefsController:self didChangeServers:self.servers];
    [self.viewController prefsController:self didChangeSelectedServer:self.server];
}
- (void)userDidRefreshServers
{
    [self startMonitoringServers];
}



#pragma mark Delete Confirmation

- (void)userDidDeleteServerShowInFinder
{
    if (!self.server.daemonFileExists) return;
    
    NSString *source = [NSString stringWithFormat:@""
                        "tell application \"Finder\"\n"
                        "reveal POSIX file \"%@\"\n"
                        "activate\n"
                        "end tell", [self.server.daemonFile stringByExpandingTildeInPath]];
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:nil];
}
- (void)userDidCancelDeleteServer
{
    // Do nothing
}
- (void)userDidDeleteServerKeepFile
{
    [self deleteServerAndDeleteFile:NO];
}
- (void)userDidDeleteServerDeleteFile
{
    [self deleteServerAndDeleteFile:YES];
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
        
        PGAuth *auth = [[PGAuth alloc] initWithDelegate:self];
        PGServer *server = self.server;
        [self.serverController runAction:action server:server auth:auth succeeded:^{
            MainThreadAfterDelay(0.2, ^{
                [self checkStatus:server];
            });
        } failed:nil];
        
    // Check Status
    } else {
        [self checkStatus:self.server];
    }
}



#pragma mark Settings

- (void)userWillEditSettings
{
    [self.searchController findInstalledServers];
    
    [self.serverController clean:self.server];
    
    [self.viewController prefsController:self willEditServerSettings:self.server];
}
- (void)userDidSelectSearchServer:(PGServer *)server
{
    [self.serverController setDirtySettings:server.settings forServer:self.server];
    
    [self.viewController prefsController:self didChangeServerSettings:self.server];
}
- (void)userDidChangeSetting:(NSString *)setting value:(NSString *)value
{
    [self.serverController setDirtySetting:setting value:value forServer:self.server];
    
    [self.viewController prefsController:self didChangeServerSetting:setting server:self.server];
}
- (void)userDidCancelSettings
{
    [self.serverController clean:self.server];
    
    [self.viewController prefsController:self didRevertServerSettings:self.server];
}
- (void)userDidRevertSettings
{
    [self.serverController clean:self.server];
    
    [self.viewController prefsController:self didRevertServerSettings:self.server];
}
- (void)userDidApplySettings
{
    PGServer *server = self.server;
    if (server.external) return;

    if (!server.dirty) return;

    PGAuth *auth = [[PGAuth alloc] initWithDelegate:self];
    PGServerAction finalAction = server.started ? PGServerStart : PGServerCreate;
    
    // Backup existing
    PGServerSettings *oldSettings = server.settings;
    PGServerSettings *newSettings = server.dirtySettings;
    
    // Show the change
    [self.serverController setSettings:newSettings forServer:server];

    // First stop and delete the existing server
    [self.serverController runAction:PGServerDelete server:self.server auth:auth succeeded:^{

        // Save
        BOOL succeeded = [self.dataStore saveServer:server];
        
        // Save failed - restore backup
        if (!succeeded) {
            [self.serverController setSettings:oldSettings forServer:server];
            return;
        }
        
        // Clear dirty settings
        [self.serverController clean:server];
        
        // Create and start (if needed) the new server
        [self.serverController runAction:finalAction server:server auth:auth succeeded:^{
            
            [self.viewController prefsController:self didApplyServerSettings:server];
            
            [self checkStatus:server];
            
        } failed:nil];
    } failed:^(NSString *error) {
        [self.serverController setSettings:oldSettings forServer:server];
        [self server:server didFailAction:PGServerDelete error:error];
    }];
}
- (void)userDidChangeServerStartup:(NSString *)startup
{
    PGServer *server = self.server;
    if (server.external) {
        [self.viewController prefsController:self didRevertServerStartup:server];
        return;
    };
    
    PGAuth *auth = [[PGAuth alloc] initWithDelegate:self];
    
    // Backup existing
    PGServerStartup oldStartup = server.settings.startup;
    PGServerStartup newStartup = ToServerStartup(startup);
    
    // Apply the change
    BOOL succeeded = [self.serverController setStartup:newStartup forServer:server];
    
    // Save
    if (succeeded) succeeded = [self.dataStore saveServer:server];
    
    // Save failed - restore backup
    if (!succeeded) {
        [self.serverController setStartup:oldStartup forServer:server];
        [self.viewController prefsController:self didRevertServerStartup:server];
        return;
    }
    
    // Run script
    [self.serverController runAction:PGServerCreate server:server auth:auth succeeded:^{
        [self checkStatus:server];
        
    } failed:^(NSString *error) {
        // Revert startup in GUI
        [self.serverController setStartup:oldStartup forServer:server];
        [self.dataStore saveServer:server];
        [self.viewController prefsController:self didRevertServerStartup:server];
        [self server:server didFailAction:PGServerCreate error:error];
    }];
}



#pragma mark Log

- (void)userDidViewLog
{
    if (!self.server.daemonLogExists) return;

    NSString *source = [NSString stringWithFormat:@""
                        "tell application \"Console\"\n"
                        "activate\n"
                        "open \"%@\"\n"
                        "end tell", [self.server.daemonLog stringByExpandingTildeInPath]];
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:nil];
}



#pragma mark PGServerDelegate

- (void)server:(PGServer *)server willRunAction:(PGServerAction)action
{
    [self.viewController prefsController:self didChangeServerStatus:server];
}
- (void)server:(PGServer *)server didSucceedAction:(PGServerAction)action
{
    [self.viewController prefsController:self didChangeServerStatus:server];
}
- (void)server:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error
{
    [self.viewController prefsController:self didChangeServerStatus:server];
}
- (void)server:(PGServer *)server didRunAction:(PGServerAction)action
{
    // Do nothing
}



#pragma mark PGSearchDelegate

- (void)didFindMoreServers:(PGSearchController *)search
{
    [self.viewController prefsController:self didChangeSearchServers:search.servers];
}



#pragma mark Private

- (AuthorizationRef)authorize:(PGAuth *)auth
{
    if (self.authorization) {
        return self.authorization;
    } else {
        return self.authorization = [self.viewController authorizeAndWait:auth];
    }
}

- (void)checkStatus:(PGServer *)server
{
    [self.serverController runAction:PGServerCheckStatus server:server auth:nil];
}

- (void)deleteServerAndDeleteFile:(BOOL)delete
{
    PGAuth *auth = [[PGAuth alloc] initWithDelegate:self];
    PGServerAction action = delete ? PGServerDelete : PGServerStop;
    
    // Run script
    PGServer *server = self.server;
    [self.serverController runAction:action server:server auth:auth succeeded:^{
        [self removeServer:server];
    } failed:nil];
}

- (void)removeServer:(PGServer *)server
{
    if (![self.servers containsObject:server]) return;
    
    DLog(@"%@", server);
    
    // Calculate which server to select after delete
    PGServer *nextServer = [self.servers objectAfter:server];
    if (!nextServer) nextServer = [self.servers objectBefore:server];
    
    // Delete the server
    [self.dataStore removeServer:server];
    
    // Get the new servers list after delete
    self.servers = self.dataStore.servers;
    
    // Tell view controller to update servers list
    [self.viewController prefsController:self didChangeServers:self.servers];
    
    // Select the next server
    if (!self.server || self.server == server || self.servers.count == 0) {
        self.server = nextServer;
        [self.viewController prefsController:self didChangeSelectedServer:self.server];
    }
}

- (void)startMonitoringServers
{
    mustBeMainThread();
    
    [self.serversMonitorManager cancel];
    self.serversMonitorManager = [[PGThreadManager alloc] init];
    
    for (PGServer *server in self.servers) [self startMonitoringServer:server];
    
    [self startMonitoringLaunchd];
}
- (void)stopMonitoringServers
{
    mustBeMainThread();
    
    [self.serversMonitorManager cancel];
    self.serversMonitorManager = nil;
}
- (void)startMonitoringServer:(PGServer *)server
{
    mustBeMainThread();
    
    PGThreadController *controller = [self.serversMonitorManager makeController];
    BackgroundThread(^{ [self pollServer:server controller:controller]; });
}
- (void)pollServer:(PGServer *)server controller:(PGThreadController *)controller
{
    // Ensure not stopped
    if (!controller.manager.enabled) { return; }
    
    // Ensure server not deleted
    __block BOOL serverExists = YES;
    MainThread(^{ serverExists = [self.servers containsObject:server]; });
    if (!serverExists) return;
    
    // Run check status
    [self checkStatus:server];
    
    // If stopped external server with no daemon file, delete it
    if (server.external && server.status == PGServerStopped && !server.daemonFileExists) {
        MainThread(^{ [self removeServer:server]; });
    }
    
    // Ensure not stopped
    if (!controller.manager.enabled) { return; }

    // Global disable auto-monitoring
    if (!PGPrefsMonitorServersEnabled) { return; }
    
    // Schedule re-run
    BackgroundThreadAfterDelay(PGServersPollTime, ^{ [self pollServer:server controller:controller]; });
}
- (void)startMonitoringLaunchd
{
    mustBeMainThread();
    
    PGThreadController *controller = [self.serversMonitorManager makeController];
    BackgroundThread(^{ [self detectExternalServers:controller]; });
}
- (void)detectExternalServers:(PGThreadController *)controller
{
    // Ensure not stopped
    if (!controller.manager.enabled) { return; }

    // Add any new external servers
    NSArray *loadedServers = [self.searchController startedServers];
    if (loadedServers.count > 0) {
        
        // Get existing servers by name
        NSArray *existingServers = self.dataStore.servers;
        NSMutableDictionary *existingLookup = existingServers.count == 0 ? nil : [NSMutableDictionary dictionaryWithCapacity:existingServers.count];
        for (PGServer *server in existingServers) {
            if (!NonBlank(server.name) || !server.external) continue;
            existingLookup[server.name] = server;
        }
        
        // Calculcate servers to add
        NSMutableArray *toAdd = [NSMutableArray arrayWithCapacity:loadedServers.count];
        for (PGServer *server in loadedServers) {
            if (!NonBlank(server.name)) continue;
            if (existingLookup[server.name]) continue;
            [toAdd addObject:server];
            
            // If server's daemon file exists, get more information from that
            if (!server.daemonFileExists) continue;
            PGServer *serverFromFile = [self.serverController serverFromDaemonFile:server.daemonFile];
            if (![serverFromFile.daemonName isEqualToString:server.daemonName]) continue;
            
            // Replace settings with file settings (because they're always more complete!)
            [self.serverController setSettings:serverFromFile.settings forServer:server];
        }
        
        // Add servers
        if (toAdd.count > 0) {
            MainThread(^{
                for (PGServer *server in toAdd) {
                    [self.dataStore saveServer:server];
                    [self startMonitoringServer:server];
                }
                
                self.servers = self.dataStore.servers;
                [self.viewController prefsController:self didChangeServers:self.servers];
                if (!self.server) {
                    self.server = self.servers.firstObject;
                    [self.viewController prefsController:self didChangeSelectedServer:self.server];
                }
            });
        }
    }
    
    // Ensure not stopped
    if (!controller.manager.enabled) { return; }

    // Global disable auto-monitoring
    if (!PGPrefsMonitorServersEnabled) { return; }
    
    // Schedule re-run
    BackgroundThreadAfterDelay(PGServersPollTime, ^{ [self detectExternalServers:controller]; });
}

@end

//
//  PGPrefsController.h
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

#import <Foundation/Foundation.h>
#import "PGSearchController.h"
#import "PGServerController.h"
#import "PGServerDataStore.h"

@class PGPrefsController;

#pragma mark - PGPrefsViewController

/**
 * Delegate that udpates the GUI in response to controller events.
 *
 * Also responsible for obtaining authorization from user.
 */
@protocol PGPrefsViewController <NSObject>

/// Should be called on a background thread so that viewController can block thread until
/// authorization animations have finished.
- (AuthorizationRef)authorizeAndWait:(PGAuth *)auth;
- (void)deauthorize;

- (void)prefsController:(PGPrefsController *)controller willEditServerSettings:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didChangeServers:(NSArray *)servers;
- (void)prefsController:(PGPrefsController *)controller didChangeSelectedServer:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didChangeServerStatus:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didChangeServerSetting:(NSString *)setting server:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didChangeServerSettings:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didApplyServerSettings:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didRevertServerSettings:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didRevertServerStartup:(PGServer *)server;
- (void)prefsController:(PGPrefsController *)controller didChangeSearchServers:(NSArray *)servers;
- (void)prefsController:(PGPrefsController *)controller willConfirmDeleteServer:(PGServer *)server;

@end



#pragma mark - PGPrefsController

/**
 * Controller that ties together a preference pane (view) and
 * a set of Postgre Servers (model).
 *
 * The controller receives user actions from the preference pane, carries out
 * corresponding actions on the Postgre Servers.
 *
 * The Postgre Servers are stored in NSUserDefaults, and are started/stopped
 * using .plist files generated in the standard Mac launchagent directories.
 */
@interface PGPrefsController : NSObject <PGServerDelegate, PGSearchDelegate>

@property (nonatomic, weak) id<PGPrefsViewController> viewController;
@property (nonatomic, strong, readonly) PGServerController *serverController;
@property (nonatomic, strong, readonly) PGSearchController *searchController;
@property (nonatomic, strong, readonly) PGServerDataStore *dataStore;

@property (nonatomic, strong, readonly) PGServer *server;
@property (nonatomic, strong, readonly) NSArray *servers;

/// The current authorization if authorized, or NULL if not authorized
@property (nonatomic, readonly) AuthorizationRef authorization;
/// The rights required to perform controller actions
- (PGRights *)rights;

- (id)initWithViewController:(id<PGPrefsViewController>)viewController;

// Lifecycle
- (void)viewDidLoad;
- (void)viewWillAppear;
- (void)viewDidAppear;
- (void)viewWillDisappear;
- (void)viewDidDisappear;
- (void)viewDidAuthorize:(AuthorizationRef)authorization;
- (void)viewDidDeauthorize;

// Servers
- (void)userDidSelectServer:(PGServer *)server;
- (void)userDidAddServer;
- (void)userDidDeleteServer;
- (BOOL)userCanRenameServer:(NSString *)name;
- (void)userDidRenameServer:(NSString *)name;
- (void)userDidCancelRenameServer;
- (void)userDidDuplicateServer;
- (void)userDidRefreshServers;

// Delete Confirmation
- (void)userDidDeleteServerShowInFinder;
- (void)userDidCancelDeleteServer;
- (void)userDidDeleteServerKeepFile;
- (void)userDidDeleteServerDeleteFile;

// Start/Stop
- (void)userDidStartStopServer;

// Settings
- (void)userDidSelectSearchServer:(PGServer *)server;
- (void)userWillEditSettings;
- (void)userDidChangeServerStartup:(NSString *)startup;
- (void)userDidChangeSetting:(NSString *)setting value:(NSString *)value;
- (void)userDidRevertSettings;
- (void)userDidApplySettings;
- (void)userDidCancelSettings;

// Log
- (void)userDidViewLog;

// PGServerDelegate
- (void)server:(PGServer *)server willRunAction:(PGServerAction)action;
- (void)server:(PGServer *)server didSucceedAction:(PGServerAction)action;
- (void)server:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error;
- (void)server:(PGServer *)server didRunAction:(PGServerAction)action;

// PGSearchDelegate
- (void)didFindMoreServers:(PGSearchController *)search;

@end

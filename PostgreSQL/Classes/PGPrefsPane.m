//
//  Postgres.m
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGPrefsPane.h"

#pragma mark - Interfaces

@interface PGPrefsPane()

/// If YES, user events will not be sent to the controller (e.g. select server)
@property (nonatomic) BOOL updatingDisplay;
/// If NO, then all user controls will be greyed-out
@property (nonatomic) BOOL enabled;
/// If NO, then the start/stop button will be greyed-out
@property (nonatomic) BOOL startStopEnabled;

- (void)initAuthorization;

- (void)showStarted;
- (void)showStopped;
- (void)showStarting;
- (void)showStopping;
- (void)showChecking;
- (void)showRetrying;
- (void)showUnknown;
- (void)showProtected;
- (void)showDirtyInSettingsWindow:(PGServer *)server;
- (void)showSettingsInSettingsWindow:(PGServer *)server;
- (void)showSettingsInMainServerView:(PGServer *)server;
- (void)showStatusInMainServerView:(PGServer *)server;
- (void)showServerInMainServerView:(PGServer *)server;
- (void)showServerInServersTable:(PGServer *)server;
- (void)showServerRenameWindow:(PGServer *)server;
- (void)showServerSettingsWindow:(PGServer *)server;

@end



#pragma mark - PGPrefsCenteredTextFieldCell

@implementation PGPrefsCenteredTextFieldCell

- (NSRect)adjustedFrameToVerticallyCenterText:(NSRect)rect
{
    NSAttributedString *string = self.attributedStringValue;
    CGFloat boundsHeight = [string boundingRectWithSize:rect.size options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading].size.height;
    NSInteger offset = floor((NSHeight(rect) - ceilf(boundsHeight))/2);
    NSRect centeredRect = NSInsetRect(rect, 0, offset);
    return centeredRect;
}
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
    [super drawInteriorWithFrame:[self adjustedFrameToVerticallyCenterText:frame] inView:view];
}

@end



#pragma mark - PGPrefsSegmentedControl

@implementation PGPrefsSegmentedControl
- (SEL)action
{
    // This allows connected menu to popup instantly
    // (because no action is returned for menu button)
    return [self menuForSegment:self.selectedSegment] != nil ? nil : [super action];
}
@end



#pragma mark - PGPrefsRenameWindow

@implementation PGPrefsRenameWindow
@end



#pragma mark - PGPrefsServerSettingsWindow

@implementation PGPrefsServerSettingsWindow
@end



#pragma mark - PGPrefsServersCell

@implementation PGPrefsServersCell
@end



#pragma mark - PGPrefsPane

@implementation PGPrefsPane

#pragma mark Lifecycle

- (void)mainViewDidLoad
{
    // Remove existing delegate
    if (self.controller) {
        DLog(@"Warning - controller already exists! Removing existing controller...");
        if (self.controller.viewController == self) self.controller.viewController = nil;
        self.controller = nil;
    }
    
    // Set servers menu
    [self.serversMenu setDelegate:self];
    [self.serversButtons setMenu:self.serversMenu forSegment:2];
    
    // Set new delegate
    self.controller = [[PGPrefsController alloc] initWithViewController:self];
    
    // Reset internal variables
    _startStopEnabled = self.startStopButton.enabled;
    _enabled = YES;
    
    // Setup subview delegates
    self.serverSettingsWindow.usernameField.delegate = self;
    self.serverSettingsWindow.binDirectoryField.delegate = self;
    self.serverSettingsWindow.dataDirectoryField.delegate = self;
    self.serverSettingsWindow.logFileField.delegate = self;
    self.serverSettingsWindow.portField.delegate = self;
    
    // Wire up authorization
    [self initAuthorization];
    
    // Call delegate DidLoad method
    [self.controller viewDidLoad];
}

- (void)willSelect
{
    [self.controller viewWillAppear];
}
- (void)didSelect
{
    [self.controller viewDidAppear];
    
    // Hack to get first responder to work
    // See http://stackoverflow.com/questions/24903165/mysterious-first-responder-change
    [self.mainView.window performSelector:@selector(makeFirstResponder:) withObject:self.serversTableView afterDelay:0.0];
}
- (void)willUnselect
{
    [self.controller viewWillDisappear];
}
- (void)didUnselect
{
    [self.controller viewDidDisappear];
}



#pragma mark Properties

- (void)setEnabled:(BOOL)enabled
{
    if (enabled == _enabled) return;
    _enabled = enabled;
    
    self.startStopButton.enabled = enabled && self.startStopEnabled;
    self.changeSettingsButton.enabled = enabled;
    self.startupAtBootCell.enabled = enabled;
    self.startupAtLoginCell.enabled = enabled;
    self.startupManualCell.enabled = enabled;
    
    self.serversButtons.enabled = enabled;
    self.noServersButtons.enabled = YES; // Always enabled, not always visible
}
- (void)setStartStopEnabled:(BOOL)startStopEnabled
{
    if (startStopEnabled == _startStopEnabled) return;
    _startStopEnabled = startStopEnabled;

    self.startStopButton.enabled = self.enabled && startStopEnabled;
}



#pragma mark PGServerSettings

- (void)controlTextDidChange:(NSNotification *)notification
{
    if (self.updatingDisplay) return;
    
    PGPrefsServerSettingsWindow *view = self.serverSettingsWindow;
    if (notification.object == view.usernameField) [self.controller userDidChangeSetting:PGServerUsernameKey value:view.usernameField.stringValue];
    else if (notification.object == view.binDirectoryField) [self.controller userDidChangeSetting:PGServerBinDirectoryKey value:view.binDirectoryField.stringValue];
    else if (notification.object == view.dataDirectoryField) [self.controller userDidChangeSetting:PGServerDataDirectoryKey value:view.dataDirectoryField.stringValue];
    else if (notification.object == view.logFileField) [self.controller userDidChangeSetting:PGServerLogFileKey value:view.logFileField.stringValue];
    else if (notification.object == view.portField) [self.controller userDidChangeSetting:PGServerPortKey value:view.portField.stringValue];
    else
        DLog(@"Unknown control: %@", notification.object);
}
- (IBAction)startupClicked:(id)sender
{
    if (self.updatingDisplay) return;
 
    NSCell *cell = [sender selectedCell];
    PGServerStartup startup;
    if (cell == self.startupAtBootCell) startup = PGServerStartupAtBoot;
    else if (cell == self.startupAtLoginCell) startup = PGServerStartupAtLogin;
    else if (cell == self.startupManualCell) startup = PGServerStartupManual;
    else return;
    
    [self.controller performSelector:@selector(userDidChangeServerStartup:) withObject:ServerStartupDescription(startup) afterDelay:0.1];
}

- (IBAction)viewLogClicked:(id)sender
{
    [self.controller userDidViewLog];
}



#pragma mark Authorization

- (BOOL)authorized
{
    return self.authorizationView.authorizationState == SFAuthorizationViewUnlockedState;
}

- (AuthorizationRef)authorization
{
    SFAuthorization *authorization = self.authorizationView.authorization;
    return authorization ? authorization.authorizationRef : NULL;
}

- (void)initAuthorization
{
    AuthorizationRights *rights = self.controller.authorizationRights;
    if (!rights) {
        DLog(@"No Authorization Rights!");
        [self.authorizationView removeFromSuperview];
        return;
    }

    self.authorizationView.authorizationRights = rights;
    self.authorizationView.delegate = self;
    [self.authorizationView updateStatus:nil];
    self.authorizationView.autoupdate = self.authorized;
}

- (AuthorizationRef)authorize
{
    if (self.authorized) return self.authorizationView.authorization.authorizationRef;
    
    self.authorizationView.flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
    BOOL authorized = [self.authorizationView authorize:self];
    self.authorizationView.flags = authorized ? kAuthorizationFlagDefaults : kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights;
    [self.authorizationView updateStatus:nil];
    return authorized ? self.authorizationView.authorization.authorizationRef : NULL;
}

- (void)deauthorize
{
    [self.authorizationView deauthorize:self.authorizationView.authorization];
    
    [self.mainView.window makeFirstResponder:self.serversTableView];
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view
{
    self.authorizationView.flags = kAuthorizationFlagDefaults;
    
    view.autoupdate = YES;
    [self.controller viewDidAuthorize:view.authorization.authorizationRef];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view
{
    view.autoupdate = NO;
    self.authorizationView.flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights;
    
    [self.controller viewDidDeauthorize];
}



#pragma mark Apply/Revert Settings

- (IBAction)changeSettingsClicked:(id)sender
{
    [self.controller userWillEditSettings];
}
- (IBAction)resetSettingsClicked:(id)sender
{
    [self.controller userDidRevertSettings];
}
- (IBAction)applySettingsClicked:(id)sender
{
    [NSApp endSheet:self.serverSettingsWindow returnCode:NSOKButton];
}
- (IBAction)cancelSettingsClicked:(id)sender
{
    [NSApp endSheet:self.serverSettingsWindow returnCode:NSCancelButton];
}



#pragma mark Servers

- (IBAction)serversButtonClicked:(NSSegmentedControl *)sender
{
    [self.mainView.window makeFirstResponder:self.serversTableView];
    
    switch (sender.selectedSegment) {
        case 0:
            [self.controller userDidAddServer];
            break;
        case 1:
            [self.controller userDidDeleteServer];
            break;
        case 2:
            // Ignore - popup handled separately
            break;
        default:
            break; // Invalid segment
    }
}

- (IBAction)renameServerClicked:(id)sender
{
    [self showServerRenameWindow:self.server];
}

- (IBAction)cancelRenameServerClicked:(id)sender
{
    [NSApp endSheet:self.serversRenameWindow returnCode:NSCancelButton];
}

- (IBAction)okRenameServerClicked:(id)sender
{
    if (![self.controller userCanRenameServer:self.serversRenameWindow.nameField.stringValue]) return;
    
    [NSApp endSheet:self.serversRenameWindow returnCode:NSOKButton];
}
     
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    // Rename
    if (sheet == self.serversRenameWindow) {
        [self.serversRenameWindow orderOut:self];
        
        // Cancelled
        if (returnCode == NSCancelButton) {
            [self.controller userDidCancelRenameServer];
            
        // Apply
        } else {
            [self.controller userDidRenameServer:self.serversRenameWindow.nameField.stringValue];
        }
        
    // Settings
    } else if (sheet == self.serverSettingsWindow) {
        [self.serverSettingsWindow orderOut:self];
        
        // Cancelled
        if (returnCode == NSCancelButton) {
            [self.controller userDidCancelSettings];
            
        // Apply
        } else {
            [self.controller userDidApplySettings];
        }
    }
}

- (void)menuWillOpen:(NSMenu *)menu
{
    [self.mainView.window makeFirstResponder:self.serversTableView];
    
}



#pragma mark Start/Stop

- (IBAction)startStopClicked:(id)sender
{
    [self.controller userDidStartStopServer];
}



#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    // Servers
    if (tableView == self.serversTableView) {
        NSInteger result = MAX(self.servers.count+1, 1);
        DLog(@"Servers Table Rows: %@", @(result));
        return result;
        
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        NSInteger result = self.searchServers.count;
        DLog(@"Search Servers Table Rows: %@", @(result));
        return result;
    }
    
    return 0;
}
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors

{
    if (tableView != self.serverSettingsWindow.serversTableView) return;
    
    self.searchServers = [self.searchServers sortedArrayUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}



#pragma mark NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        return row == 0 ? 16 : 36;
        
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        return 18;
    }
    return 44;
}
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        if (row == 0) return NO;
        if (!self.updatingDisplay) [self.controller userDidSelectServer:self.servers[row-1]];
        // Always scroll to beginning of table when selecting top-most datacell
        // That way, header cell is visible, rather than tending to be 'off-screen'
        if (row == 1) [tableView scrollToBeginningOfDocument:self];
        return YES;
        
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        [self.controller userDidSelectSearchServer:self.searchServers[row]];
        return YES;
    }
    
    return YES;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        // Header
        if (row == 0) {
            NSTableCellView *result = [tableView makeViewWithIdentifier:@"HeaderCell" owner:self];
            result.textField.stringValue = @"DATABASE SERVERS";
            return result;
            
        // Server
        } else {
            PGPrefsServersCell *result = [tableView makeViewWithIdentifier:@"DataCell" owner:self];
            PGServer *server = self.servers[row-1];
            [self configureServersCell:result forServer:server];
            return result;
        }
    
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        
        PGServer *server = self.searchServers.count == 0 ? nil : self.searchServers[row];
        NSString *cellIdentifier = nil;
        NSString *value = nil;
        
        // Name
        if ([tableColumn.identifier isEqualToString:@"Name"]) {
            cellIdentifier = @"NameCell";
            value = server.name;
            
        // Domain
        } else if ([tableColumn.identifier isEqualToString:@"Domain"]) {
            cellIdentifier = @"DomainCell";
            value = server.domain;
            
        // Unknown
        } else return nil;

        NSTableCellView *result = [tableView makeViewWithIdentifier:cellIdentifier owner:self];
        result.textField.stringValue = value?:@"";
        return result;
    }
    
    return nil;
}
- (void)configureServersCell:(PGPrefsServersCell *)cell forServer:(PGServer *)server
{
    // Name
    cell.textField.stringValue = server.name?:@"Name Not Found";
    
    // Icon & Status
    NSString *statusText = nil;
    NSString *imageName = nil;
    if (server.needsAuthorization && !self.authorized) {
        imageName = NSImageNameLockLockedTemplate;
        statusText = @"Protected";
    } else {
        statusText = ServerStatusDescription(server.status);
        switch (server.status) {
            case PGServerStarted:
                if (NonBlank(server.settings.port)) statusText = [NSString stringWithFormat:@"%@ on port %@", statusText, server.settings.port];
                imageName = NSImageNameStatusAvailable;
                break;
            case PGServerStopped:
                imageName = NSImageNameStatusUnavailable;
                break;
            case PGServerRetrying: // Fall through
            case PGServerStarting: // Fall through
            case PGServerStopping: // Fall through
            case PGServerUpdating:
                imageName = NSImageNameStatusPartiallyAvailable;
                break;
            default:
                imageName = NSImageNameStatusNone;
        }
    }
    cell.statusTextField.stringValue = statusText;
    cell.imageView.image = [NSImage imageNamed:imageName];
}



#pragma mark PGPrefsViewController

- (void)prefsController:(PGPrefsController *)controller willEditServerSettings:(PGServer *)server
{
    [self showServerSettingsWindow:server];
}
- (void)prefsController:(PGPrefsController *)controller didChangeServers:(NSArray *)servers
{
    self.updatingDisplay = YES;
 
    DLog(@"Servers: %@", @(servers.count));
    
    PGServer *server = [self selectedServer];
    self.servers = servers;
    [self.serversTableView reloadData];
    [self selectServer:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeSelectedServer:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self selectServer:server];
    [self showServerInMainServerView:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeServerStatus:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    if ([self selectedServer] == server) [self showStatusInMainServerView:server];
    
    [self showServerInServersTable:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didDirtyServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showDirtyInSettingsWindow:server];

    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didApplyServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self selectServer:server];
    [self showSettingsInMainServerView:server];
    [self showServerInServersTable:server];

    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didRevertServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showSettingsInSettingsWindow:server];
    [self.serverSettingsWindow.serversTableView deselectAll:self];

    self.updatingDisplay = NO;
}
- (void)prefsController:(PGPrefsController *)controller didRevertServerStartup:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self performSelector:@selector(showServerStartup:) withObject:server afterDelay:0.0];
    
    self.updatingDisplay = NO;
    
}
- (void)revertServerStartup:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showServerStartup:server];
    
    self.updatingDisplay = NO;
}
- (void)prefsController:(PGPrefsController *)controller didChangeSearchServers:(NSArray *)servers
{
    self.updatingDisplay = YES;
    
    NSArray *sortDescriptors = self.serverSettingsWindow.serversTableView.sortDescriptors;
    
    if (sortDescriptors.count == 0) sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    
    self.searchServers = [servers sortedArrayUsingDescriptors:sortDescriptors];
    self.serverSettingsWindow.serversTableView.sortDescriptors = sortDescriptors;
    
    [self.serverSettingsWindow.serversTableView reloadData];
    
    self.updatingDisplay = NO;
}



#pragma mark Private

- (NSUInteger)rowForServer:(PGServer *)server
{
    NSUInteger result = [self.servers indexOfObject:server];
    return result == NSNotFound ? result : result+1;
}

- (PGServer *)selectedServer
{
    if (self.servers.count == 0) return nil;
    
    NSInteger row = self.serversTableView.selectedRow;
    
    if (row < 0 || row-1 >= self.servers.count) return nil;
    
    return self.servers[row-1];
}

- (void)selectServer:(PGServer *)server
{
    NSUInteger row = [self.servers indexOfObject:server];
    if (row == NSNotFound) return;
    
    [self.serversTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
    
    [self.mainView.window makeFirstResponder:self.serversTableView];
}

- (void)showStarted
{
    NSString *startedPath = [[self bundle] pathForResource:@"started" ofType:@"png"];
    NSImage *started = [[NSImage alloc] initWithContentsOfFile:startedPath];
    
    self.startStopButton.title = @"Stop PostgreSQL";
    self.infoField.stringValue = @"The PostgreSQL Database Server is started and ready for client connections.\nTo shut down the server, use the \"Stop PostgreSQL\" button.";
    self.statusField.stringValue = @"Running";
    self.statusField.textColor = PGServerStartedColor;
    self.statusImage.image = started;
}

- (void)showStopped
{
    NSString *stoppedPath = [[self bundle] pathForResource:@"stopped" ofType:@"png"];
    NSImage *stopped = [[NSImage alloc] initWithContentsOfFile:stoppedPath];
    
    self.startStopButton.title = @"Start PostgreSQL";
    self.infoField.stringValue = @"The PostgreSQL Database Server is currently stopped.\nTo start it, use the \"Start PostgreSQL\" button.";
    self.statusField.stringValue = @"Stopped";
    self.statusField.textColor = PGServerStoppedColor;
    self.statusImage.image = stopped;
}

- (void)showStarting
{
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    self.statusField.stringValue = @"Starting...";
    self.statusField.textColor = PGServerStartingColor;
    self.statusImage.image = checking;
}

- (void)showStopping
{
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    self.statusField.stringValue = @"Stopping...";
    self.statusField.textColor = PGServerStoppingColor;
    self.statusImage.image = checking;
}

- (void)showChecking
{
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    
    self.startStopButton.title = @"PostgreSQL";
    self.infoField.stringValue = @"The running status of the PostgreSQL Database Server is currently being checked.";
    self.statusField.stringValue = @"Checking...";
    self.statusField.textColor = PGServerCheckingColor;
    self.statusImage.image = checking;
}

- (void)showRetrying
{
    NSString *checkingPath = [[self bundle] pathForResource:@"retrying" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    
    self.startStopButton.title = @"Stop PostgreSQL";
    self.infoField.stringValue = @"The PostgreSQL Database Server has failed to start. Please view the log for details.";
    self.statusField.stringValue = @"Retrying...";
    self.statusField.textColor = PGServerRetryingColor;
    self.statusImage.image = checking;
}

- (void)showUnknown
{
    NSString *unknownPath = [[self bundle] pathForResource:@"unknown" ofType:@"png"];
    NSImage *unknownImage = [[NSImage alloc] initWithContentsOfFile:unknownPath];
    
    self.startStopButton.title = @"PostgreSQL";
    self.infoField.stringValue = @"The running status of the PostgreSQL Database Server is not currently known.\nPlease check the server settings and try again.";
    self.statusField.stringValue = @"Unknown";
    self.statusField.textColor = PGServerStatusUnknownColor;
    self.statusImage.image = unknownImage;
}

- (void)showProtected
{
    [self showUnknown];
    
    self.infoField.stringValue = @"The PostgreSQL Database Server is run under a different user account. Please click the lock.";
    self.statusField.stringValue = @"Protected";
}

- (void)showError:(NSString *)errMsg
{
    // No error
    if (!errMsg) {
        self.errorField.stringValue = @"";
        self.errorView.hidden = YES;
        self.infoField.hidden = NO;
        
    // Error
    } else {
        self.errorField.stringValue = errMsg;
        self.errorView.hidden = NO;
        self.infoField.hidden = YES;
    }
}

- (void)showDirtyInSettingsWindow:(PGServer *)server
{
    self.serverSettingsWindow.revertSettingsButton.enabled = server.dirtySettings != nil;
    self.serverSettingsWindow.applySettingsButton.enabled = server.dirtySettings != nil;
    
    PGServerSettings *settings = server.dirtySettings ?: server.settings;
    self.serverSettingsWindow.invalidBinDirectoryImage.hidden = !settings.invalidBinDirectory;
    self.serverSettingsWindow.invalidDataDirectoryImage.hidden = !settings.invalidDataDirectory;
}
- (void)showSettingsInSettingsWindow:(PGServer *)server
{
    PGServerSettings *settings = server.dirtySettings ?: server.settings;
    self.serverSettingsWindow.usernameField.stringValue = settings.username?:@"";
    self.serverSettingsWindow.binDirectoryField.stringValue = settings.binDirectory?:@"";
    self.serverSettingsWindow.dataDirectoryField.stringValue = settings.dataDirectory?:@"";
    self.serverSettingsWindow.logFileField.stringValue = settings.logFile?:@"";
    self.serverSettingsWindow.portField.stringValue = settings.port?:@"";
    
    [self showDirtyInSettingsWindow:server];
    
    // Focus on problem field
    NSControl *focus = self.serverSettingsWindow.serversTableView;
    if (settings.invalidBinDirectory) focus = self.serverSettingsWindow.binDirectoryField;
    else if (settings.invalidDataDirectory) focus = self.serverSettingsWindow.dataDirectoryField;
    [self.serverSettingsWindow makeFirstResponder:focus];
}
- (void)showSettingsInMainServerView:(PGServer *)server
{
    PGServerSettings *settings = server.settings;
    self.usernameField.stringValue = settings.username?:@"";
    self.binDirectoryField.stringValue = settings.binDirectory?:@"";
    self.dataDirectoryField.stringValue = settings.dataDirectory?:@"";
    self.logFileField.stringValue = settings.logFile?:@"";
    self.portField.stringValue = settings.port?:@"";
    
    self.viewLogButton.enabled = server.logExists;
    
    [self showServerStartup:self.server];
}
- (void)showServerStartup:(PGServer *)server;
{
    NSCell *cell;
    switch (server.settings.startup) {
        case PGServerStartupAtBoot: cell = self.startupAtBootCell; break;
        case PGServerStartupAtLogin: cell = self.startupAtLoginCell; break;
        default: cell = self.startupManualCell; break;
    }
    [self.startupMatrix selectCell:cell];
}
- (void)showStatusInMainServerView:(PGServer *)server
{
    [self showError:server.error];
    
    if (server.needsAuthorization && !self.authorized) {
        [self showProtected];
    } else {
        switch (server.status) {
            case PGServerStarted: [self showStarted]; break;
            case PGServerStarting: [self showStarting]; break;
            case PGServerStopping: [self showStopping]; break;
            case PGServerStopped: [self showStopped]; break;
            case PGServerRetrying: [self showRetrying]; break;
            default: [self showUnknown]; break;
        }
    }
    
    self.viewLogButton.enabled = server.logExists;
    
    self.startStopButton.hidden = server.status == PGServerStatusUnknown;
    self.enabled = !server.processing;
    
    if (server.processing) [self.statusSpinner startAnimation:self];
    else [self.statusSpinner stopAnimation:self];
}

- (void)showServerInMainServerView:(PGServer *)server
{
    DLog(@"Server: %@", server);
    
    self.server = server;
    
    // No server
    if (!server) {
        [self.serverNoServerTabs selectTabViewItemWithIdentifier:@"noserver"];
        self.authorizationView.hidden = YES;
        self.serversButtons.hidden = YES;
        self.noServersButtons.hidden = NO;
        
        // Reset startup button to Manual
        [self.startupMatrix selectCell:self.startupManualCell];
        
        // Disable everything except "Add server" button
        self.enabled = NO;
        
    // Server
    } else {
        [self.serverNoServerTabs selectTabViewItemWithIdentifier:@"server"];
        self.authorizationView.hidden = NO;
        self.serversButtons.hidden = NO;
        self.noServersButtons.hidden = YES;
        
        [self showSettingsInMainServerView:server];
        [self showStatusInMainServerView:server];
    }
}

- (void)showServerInServersTable:(PGServer *)server
{
    NSUInteger row = [self rowForServer:server];
    
    if (row == NSNotFound) return;
    
    [self.serversTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)showServerSettingsWindow:(PGServer *)server
{
    [self.serverSettingsWindow.serversTableView deselectAll:self];
    [self.serverSettingsWindow.serversTableView scrollRowToVisible:0];
    [self showSettingsInSettingsWindow:server];
    [NSApp beginSheet:self.serverSettingsWindow modalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    [self.serverSettingsWindow orderFront:self];
}

- (void)showServerRenameWindow:(PGServer *)server
{
    self.serversRenameWindow.nameField.stringValue = server.name;
    
    [NSApp beginSheet:self.serversRenameWindow modalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    [self.serversRenameWindow orderFront:self];
}

@end

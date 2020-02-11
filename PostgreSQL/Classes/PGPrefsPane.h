//
//  Postgres.h
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "PGPrefsController.h"
#import "PGServer.h"

#pragma mark - PGPrefsCenteredTextFieldCell

/**
 * A textfield cell whose content is center-aligned vertically
 */
@interface PGPrefsCenteredTextFieldCell : NSTextFieldCell
@end



#pragma mark - PGPrefsNonClickableTextField

/**
 * A textfield that passes clicks to underneath view.
 */
@interface PGPrefsNonClickableTextField : NSTextField
@end



#pragma mark - PGPrefsSegmentedControl

/**
 * A segmented cell whose sole purpose is to allow an NSSegmentedControl to popup
 * a menu when any of its segments are clicked that have a menu attached to them.
 */
@interface PGPrefsSegmentedControl : NSSegmentedCell
@end



#pragma mark - PGPrefsRenameWindow

/**
 * A popup window with textbox for user to enter new name for server.
 */
@interface PGPrefsRenameWindow : NSWindow
@property (weak) IBOutlet NSTextField *nameField;
@end



#pragma mark - PGPrefsDeleteWindow

/**
 * A popup window with buttons for confirming deletion of external server.
 */
@interface PGPrefsDeleteWindow : NSWindow
@property (weak) IBOutlet NSTextField *daemonFile;
@property (weak) IBOutlet NSTextField *daemonDir;
@end



#pragma mark - PGPrefsErrorWindow

/**
 * A popup window showing the full output of running a server command.
 */
@interface PGPrefsErrorWindow : NSWindow
@property (unsafe_unretained) IBOutlet NSTextView *errorView;
@end



#pragma mark - PGPrefsServerSettingsWindow

/**
 * A popup window for editing a server's settings.
 */
@interface PGPrefsServerSettingsWindow : NSWindow
@property (weak) IBOutlet NSTableView *serversTableView;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *binDirectoryField;
@property (weak) IBOutlet NSTextField *dataDirectoryField;
@property (weak) IBOutlet NSTextField *logFileField;
@property (weak) IBOutlet NSTextField *portField;
@property (weak) IBOutlet NSImageView *invalidUsernameImage;
@property (weak) IBOutlet NSImageView *invalidBinDirectoryImage;
@property (weak) IBOutlet NSImageView *invalidDataDirectoryImage;
@property (weak) IBOutlet NSImageView *invalidLogFileImage;
@property (weak) IBOutlet NSImageView *invalidPortImage;
@property (weak) IBOutlet NSButton *revertSettingsButton;
@property (weak) IBOutlet NSButton *applySettingsButton;
@end



#pragma mark - PGPrefsServersHeaderCell

/**
 * The custom header cell used in the Postgre Database Servers table on the preference pane.
 */
@interface PGPrefsServersHeaderCell : NSTableCellView
@property (nonatomic, weak) IBOutlet NSButton *refreshButton;
@end



#pragma mark - PGPrefsServersCell

/**
 * The custom cell used in the Postgre Database Servers table on the preference pane.
 */
@interface PGPrefsServersCell : NSTableCellView
@property (nonatomic, weak) IBOutlet NSTextField *statusTextField;
@property (nonatomic, weak) IBOutlet NSImageView *externalIcon;
@end



#pragma mark - PGPrefsPane

/**
 * Preference pane for administering (i.e. starting/stopping) PostgreSQL servers.
 *
 * Note this class is the entry point into the application.
 */
@interface PGPrefsPane : NSPreferencePane <PGPrefsViewController, NSTabViewDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>

@property (nonatomic, strong) PGPrefsController *controller;

@property (nonatomic, strong) PGServer *server;
@property (nonatomic, strong) NSArray *servers;
@property (nonatomic, strong) NSArray *searchServers;

// Server/No-Server
@property (weak) IBOutlet NSTabView *serverNoServerTabs;

// Current Settings
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *binDirectoryField;
@property (weak) IBOutlet NSTextField *dataDirectoryField;
@property (weak) IBOutlet NSTextField *logFileField;
@property (weak) IBOutlet NSTextField *portField;
@property (weak) IBOutlet NSImageView *invalidUsernameImage;
@property (weak) IBOutlet NSImageView *invalidBinDirectoryImage;
@property (weak) IBOutlet NSImageView *invalidDataDirectoryImage;
@property (weak) IBOutlet NSImageView *invalidLogFileImage;
@property (weak) IBOutlet NSImageView *invalidPortImage;
@property (weak) IBOutlet NSMatrix *startupMatrix;
@property (weak) IBOutlet NSButtonCell *startupAtBootCell;
@property (weak) IBOutlet NSButtonCell *startupAtLoginCell;
@property (weak) IBOutlet NSButtonCell *startupManualCell;
@property (nonatomic) PGServerStartup startup;
- (void)controlTextDidChange:(NSNotification *)notification;
- (IBAction)startupClicked:(id)sender;

// Log
@property (weak) IBOutlet NSButton *viewLogButton;
- (IBAction)viewLogClicked:(id)sender;

// Status
@property (weak) IBOutlet NSImageView *statusImage;
@property (weak) IBOutlet NSTextField *statusField;
@property (weak) IBOutlet NSProgressIndicator *statusSpinner;
@property (weak) IBOutlet NSTextField *infoField;
@property (weak) IBOutlet NSView *errorView;
@property (weak) IBOutlet NSTextField *errorField;
@property (strong) IBOutlet PGPrefsErrorWindow *errorWindow;
- (IBAction)showErrorWindowClicked:(id)sender;
- (IBAction)closeErrorWindowClicked:(id)sender;

// Apply/Revert Settings
@property (strong) IBOutlet PGPrefsServerSettingsWindow *serverSettingsWindow;
@property (weak) IBOutlet NSButton *changeSettingsButton;
- (IBAction)changeSettingsClicked:(id)sender;
- (IBAction)resetSettingsClicked:(id)sender;
- (IBAction)applySettingsClicked:(id)sender;
- (IBAction)cancelSettingsClicked:(id)sender;

// Servers
@property (weak) IBOutlet NSTableView *serversTableView;
@property (strong) IBOutlet NSMenu *serversMenu;
@property (strong) IBOutlet PGPrefsRenameWindow *renameServerWindow;
@property (weak) IBOutlet NSMenuItem *renameServerButton;
@property (weak) IBOutlet NSSegmentedControl *serversButtons;
@property (weak) IBOutlet NSSegmentedControl *noServersButtons;
- (IBAction)serversButtonClicked:(id)sender;
- (IBAction)renameServerClicked:(id)sender;
- (IBAction)cancelRenameServerClicked:(id)sender;
- (IBAction)okRenameServerClicked:(id)sender;
- (IBAction)duplicateServerClicked:(id)sender;
- (IBAction)refreshServersClicked:(id)sender;

// Delete Confirmation
@property (strong) IBOutlet PGPrefsDeleteWindow *deleteServerWindow;
- (IBAction)cancelDeleteServerClicked:(id)sender;
- (IBAction)deleteServerDeleteFileClicked:(id)sender;
- (IBAction)deleteServerKeepFileClicked:(id)sender;
- (IBAction)deleteServerShowInFinderClicked:(id)sender;

// Start/Stop
@property (weak) IBOutlet NSButton *startStopButton;
- (IBAction)startStopClicked:(id)sender;

// Authorization
@property (nonatomic, weak) IBOutlet SFAuthorizationView *authorizationView;
- (AuthorizationRef)authorize;
- (void)deauthorize;
- (BOOL)authorized;
- (AuthorizationRef)authorization;

// NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;

// NSTableViewDelegate
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row;

// PGPrefsDelegate
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


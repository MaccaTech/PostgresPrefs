//
//  PGPrefsPane.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 17/12/11.
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



#pragma mark - PGPrefsStoryboardTextView

/**
 * A textview that can preserve its Storyboard text-styling when changing its text.
 */
@interface PGPrefsStoryboardTextView : NSTextView
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey,id> *storyboardStyle;
- (void)setAttributedStringUsingStoryboardStyle:(NSAttributedString *)attributedString NS_SWIFT_NAME(setUsingStoryboardStyle(attributedString:));
@end



#pragma mark - PGPrefsCenteredTextView
/**
 * A textview whose content is center-aligned vertically
 */
@interface PGPrefsCenteredTextView : PGPrefsStoryboardTextView
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



#pragma mark - PGPrefsToggleViews

/**
 * An imageview that removes its dimensions from autolayout when it is hidden.
 */
@interface PGPrefsToggleImageView : NSImageView
@end

/**
 * A button that removes its dimensions from autolayout when it is hidden.
 */
@interface PGPrefsToggleButton : NSButton
@end



#pragma mark - PGPrefsShowAndWaitPopover

/**
 * For tracking when a view is drawn.
 */
@protocol PGPrefsDidDrawViewDelegate <NSObject>
- (void)viewDidDraw:(NSView *)view;
@end

/**
 * Notifies its delegate whenever a draw is done.
 */
@interface PGPrefsDidDrawView : NSView
@property (nonatomic, weak) id<PGPrefsDidDrawViewDelegate> delegate;
@end

/**
 * @abstract A popover that blocks a background thread waiting until it is shown.
 *
 * On macOS Monterey (not on earlier versions) a popover will fail to appear if a modal
 * password prompt is shown simultaneously. This class allows us to delay launching
 * a modal password prompt until the popover is showing on the screen.
 *
 * @note This popover's view must be a PGPrefsDidDrawView
 */
@interface PGPrefsShowAndWaitPopover : NSPopover <PGPrefsDidDrawViewDelegate>
- (void)showRelativeToRect:(NSRect)positioningRect
                    ofView:(NSView *)positioningView
             preferredEdge:(NSRectEdge)preferredEdge
 waitUntilShownWithTimeout:(NSTimeInterval)timeout;
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
@property (weak) IBOutlet NSTextField *infoField;
@end



#pragma mark - PGPrefsInfoWindow

/**
 * A popup window showing e.g. error details, authorization info.
 */
@interface PGPrefsInfoWindow : NSWindow
@property (weak) IBOutlet NSTextField *titleField;
@property (unsafe_unretained) IBOutlet PGPrefsStoryboardTextView *detailsView;
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
@property (nonatomic, weak) IBOutlet PGPrefsToggleButton *refreshButton;
@end



#pragma mark - PGPrefsServersCell

/**
 * The custom cell used in the Postgre Database Servers table on the preference pane.
 */
@interface PGPrefsServersCell : NSTableCellView
@property (nonatomic, weak) IBOutlet NSTextField *statusTextField;
@property (nonatomic, weak) IBOutlet PGPrefsToggleImageView *externalIcon;
@property (weak) IBOutlet NSLayoutConstraint *externalIconSpacing;
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

// Splash screen
@property (weak) IBOutlet NSImageView *splashLogo;

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
@property (weak) IBOutlet NSButton *errorButton;
@property (weak) IBOutlet NSTextField *errorField;
@property (strong) IBOutlet PGPrefsInfoWindow *errorWindow;
@property (strong) IBOutlet PGPrefsInfoWindow *authInfoWindow;
@property (strong) IBOutlet PGPrefsShowAndWaitPopover *authPopover;

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
- (AuthorizationRef)authorizeAndWait:(PGAuth *)auth;
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


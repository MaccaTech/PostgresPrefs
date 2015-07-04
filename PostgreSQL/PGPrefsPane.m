//
//  Postgres.m
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import "PGPrefsPane.h"
#import "PGPrefsController.h"

#pragma mark - Constants

NSString *const PGPrefsUsernameKey      = @"Username";
NSString *const PGPrefsBinDirectoryKey  = @"BinDirectory";
NSString *const PGPrefsDataDirectoryKey = @"DataDirectory";
NSString *const PGPrefsLogFileKey       = @"LogFile";
NSString *const PGPrefsPortKey          = @"Port";
NSString *const PGPrefsAutoStartupKey   = @"AutoStartup";



#pragma mark - Interfaces

@interface PGPrefsPane()
    @property (nonatomic) BOOL autoStartupChangedBySystem;
    @property (nonatomic) BOOL editingSettings;
    @property (nonatomic) BOOL invalidSettings;
    @property (nonatomic) BOOL canStartStop;
    @property (nonatomic) BOOL canRefresh;
    @property (nonatomic) BOOL canChangeAutoStartup;
@end



#pragma mark - PGPrefsPane

@implementation PGPrefsPane

- (NSString *)username
{
    return [self.settingsUsername stringValue];
}
- (void)setUsername:(NSString *)val
{
    [self.settingsUsername setStringValue:[val trimToNil]?:@""];
}
- (NSString *)binDirectory
{
    return [self.settingsBinDir stringValue];
}
- (void)setBinDirectory:(NSString *)val
{
    [self.settingsBinDir setStringValue:[val trimToNil]?:@""];
}
- (NSString *)dataDirectory
{
    return [self.settingsDataDir stringValue];
}
- (void)setDataDirectory:(NSString *)val
{
    [self.settingsDataDir setStringValue:[val trimToNil]?:@""];
}
- (NSString *)logFile
{
    return [self.settingsLogFile stringValue];
}
- (void)setLogFile:(NSString *)val
{
    [self.settingsLogFile setStringValue:[val trimToNil]?:@""];
}
- (NSString *)port
{
    return [self.settingsPort stringValue];
}
- (void)setPort:(NSString *)val
{
    [self.settingsPort setStringValue:[val trimToNil]?:@""];
}
- (BOOL)autoStartup
{
    return self.autoStartupCheckbox.state == NSOnState;
}
- (void)setAutoStartup:(BOOL)enabled
{
    self.autoStartupChangedBySystem = YES;
    self.autoStartupCheckbox.state = enabled ? NSOnState : NSOffState;
    self.autoStartupChangedBySystem = NO;
}

- (BOOL)authorized
{
    return [self.authView authorizationState] == SFAuthorizationViewUnlockedState;
}

- (AuthorizationRef)authorization
{
    return [[self.authView authorization] authorizationRef];
}

- (void)initAuthorization
{
    AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
    [self.authView setAuthorizationRights:&rights];
    self.authView.delegate = self;
    [self.authView updateStatus:nil];
    [self.authView setAutoupdate:YES];
}

- (void)destroyAuthorization
{
    [self.authView deauthorize:[self.authView authorization]];
}

- (void)postponeAuthorizationTimeout
{
    if (self.authorized) {
        // No good way to do this at present - this is just a stub function
        // in case a method presents itself in future.
    }
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view
{
    // Reset editing settings mode first
    self.editingSettings = NO;

    // Delegate
    [self.delegate postgrePrefsDidAuthorize:self];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view
{
    [self.delegate postgrePrefsDidDeauthorize:self];
    
    // Reset editing settings mode
    self.editingSettings = NO;
}

- (BOOL)wasEditingSettings
{
    return self.editingSettings;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([tabView indexOfTabViewItem:tabViewItem] == 0) {
        if (self.editingSettings) {
            [self postponeAuthorizationTimeout];
            [self.delegate postgrePrefsDidFinishEditingSettings:self];
        }
        self.editingSettings = NO;
    } else {
        self.editingSettings = YES;
    }
}

- (void)mainViewDidLoad
{
    // Remove existing delegate
    if ([self delegate]) {
        DLog(@"Warning - delegate already exists! Removing existing delegate...");
        [self setDelegate:nil];
    }
    
    // Set new delegate
    [self setDelegate:[[PGPrefsController alloc] init]];

    // Reset internal variables
    _invalidSettings = NO;
    _canStartStop = YES;
    _canRefresh = YES;
    _canChangeAutoStartup = YES;
    _editingSettings = NO;

    // Listen for tab changes
    self.mainTabs.delegate = self;
    
    // Call delegate DidLoad method
    [self.delegate postgrePrefsDidLoad:self];
}

- (void)willUnselect
{
    [self.delegate postgrePrefsWillUnselect:self];

    // Reset editing settings mode
    self.editingSettings = NO;
    
    // Ensure saved preferences are written to disk
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)savedPreferences
{
    return [[[NSUserDefaults standardUserDefaults] persistentDomainForName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]] stringDictionary];
}
- (void)setSavedPreferences:(NSDictionary *)prefs
{
    // Remove existing prefs
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    
    // Save new prefs
    prefs = [prefs stringDictionary];
    if (prefs.nonBlank) {
        [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
    }
}

- (NSDictionary *)guiPreferences
{
    return [@{
             PGPrefsUsernameKey:self.username,
             PGPrefsBinDirectoryKey:self.binDirectory,
             PGPrefsDataDirectoryKey:self.dataDirectory,
             PGPrefsLogFileKey:self.logFile,
             PGPrefsPortKey:self.port,
             PGPrefsAutoStartupKey:(self.autoStartup ? @"Yes" : @"No")
    } stringDictionary];
}
- (void)setGuiPreferences:(NSDictionary *)prefs
{
    prefs = [prefs stringDictionary];
    
    self.username = prefs[PGPrefsUsernameKey];
    self.binDirectory = prefs[PGPrefsBinDirectoryKey];
    self.dataDirectory = prefs[PGPrefsDataDirectoryKey];
    self.logFile = prefs[PGPrefsLogFileKey];
    self.port = prefs[PGPrefsPortKey];
    BOOL autoStartup = [prefs[PGPrefsAutoStartupKey] isEqualToString:@"Yes"] || [prefs[PGPrefsAutoStartupKey] isEqualToString:@"true"];
    self.autoStartup = autoStartup;
}

- (void)setCanStartStop:(BOOL)canStartStop
{
    if (canStartStop == _canStartStop) return;
    
    if (canStartStop && self.invalidSettings) return;
    
    _canStartStop = canStartStop;
    
    self.startStopButton.enabled = canStartStop;
}
- (void)setCanRefresh:(BOOL)canRefresh
{
    if (canRefresh == _canRefresh) return;
    _canRefresh = canRefresh;
    
    self.refreshButton.enabled = canRefresh;
}
- (void)setCanChangeAutoStartup:(BOOL)canChangeAutoStartup
{
    if (canChangeAutoStartup == _canChangeAutoStartup) return;
    
    if (canChangeAutoStartup && self.invalidSettings) return;
    
    _canChangeAutoStartup = canChangeAutoStartup;
    
    self.autoStartupCheckbox.enabled = canChangeAutoStartup;
}

- (void)displayStarted
{
    NSString *startedPath = [[self bundle] pathForResource:@"started" ofType:@"png"];
    NSImage *started = [[NSImage alloc] initWithContentsOfFile:startedPath];
    
    [self.startStopButton setTitle:@"Stop PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The PostgreSQL Database Server is started and ready for client connections.\nTo shut down the server, use the \"Stop PostgreSQL\" button."];
    [self.statusLabel setTitleWithMnemonic:@"Running"];
    [self.statusLabel setTextColor:[NSColor greenColor]];
    [self.startStopInfo setTitleWithMnemonic:@"If you stop the server, you and your applications will not be able to use PostgreSQL and all current connections will be closed."];
    [self.statusImage setImage:started];        
    
    self.invalidSettings = NO;
    self.canStartStop = YES;
    self.canRefresh = YES;
    self.canChangeAutoStartup = YES;
    
    [self.spinner stopAnimation:self];
}

- (void)displayStopped
{
    NSString *stoppedPath = [[self bundle] pathForResource:@"stopped" ofType:@"png"];
    NSImage *stopped = [[NSImage alloc] initWithContentsOfFile:stoppedPath];
    
    [self.startStopButton setTitle:@"Start PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The PostgreSQL Database Server is currently stopped.\nTo start it, use the \"Start PostgreSQL\" button."];
    [self.statusLabel setTitleWithMnemonic:@"Stopped"];
    [self.statusLabel setTextColor:[NSColor redColor]];
    [self.startStopInfo setTitleWithMnemonic:@""];
    [self.statusImage setImage:stopped];
    
    self.invalidSettings = NO;
    self.canStartStop = YES;
    self.canRefresh = YES;
    self.canChangeAutoStartup = YES;
    
    [self.spinner stopAnimation:self];
}

- (void)displayStarting
{
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    [self.statusLabel setTitleWithMnemonic:@"Starting..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.statusImage setImage:checking];
    
    self.canStartStop = NO;
    self.canRefresh = NO;
    self.canChangeAutoStartup = NO;
    
    [self.spinner startAnimation:self];
}

- (void)displayStopping {
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    [self.statusLabel setTitleWithMnemonic:@"Stopping..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.statusImage setImage:checking];
    
    self.canStartStop = NO;
    self.canRefresh = NO;
    self.canChangeAutoStartup = NO;
    
    [self.spinner startAnimation:self];
}

- (void)displayChecking
{
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    
    [self.startStopButton setTitle:@"PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The running status of the PostgreSQL Database Server is not currently known."];
    [self.statusLabel setTitleWithMnemonic:@"Checking..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.startStopInfo setTitleWithMnemonic:@""];
    [self.statusImage setImage:checking];
    
    self.canStartStop = NO;
    self.canRefresh = NO;
    self.canChangeAutoStartup = NO;
    
    [self.spinner startAnimation:self];
    
    [self displayAutoStartupNoError];
}

- (void)displayUnknown
{
    NSString *stoppedPath = [[self bundle] pathForResource:@"stopped" ofType:@"png"];
    NSImage *stopped = [[NSImage alloc] initWithContentsOfFile:stoppedPath];
    
    [self.startStopButton setTitle:@"PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The running status of the PostgreSQL Database Server is not currently known."];
    [self.statusLabel setTitleWithMnemonic:@"Unknown"];
    [self.statusLabel setTextColor:[NSColor redColor]];
    [self.statusImage setImage:stopped];
    if (! self.startStopInfo.stringValue.nonBlank) {
        [self.startStopInfo setTitleWithMnemonic:@"Please check the values in the Settings tab and try again."];
    }
    
    self.invalidSettings = YES;
    self.canStartStop = NO;
    self.canRefresh = YES;
    self.canChangeAutoStartup = NO;
    
    [self.spinner stopAnimation:self];
}

- (void)displayLocked
{
    [self.authTabs selectTabViewItemWithIdentifier:@"locked"];
}

- (void)displayUnlocked
{
    NSString *identifier = self.authorized ? @"unlocked" : @"locked";
    [self.authTabs selectTabViewItemWithIdentifier:identifier];
    [self.mainTabs selectTabViewItemAtIndex:0];
}

- (void)displayWillChangeAutoStartup
{
    self.canChangeAutoStartup = NO;
    self.canRefresh = NO;
    self.canStartStop = NO;
    
    [self.autoStartupSpinner startAnimation:self];
}

- (void)displayDidChangeAutoStartup
{
    self.canChangeAutoStartup = YES;
    self.canRefresh = YES;
    self.canStartStop = YES;

    [self.autoStartupSpinner stopAnimation:self];
}

- (bool)isError
{
    return ![self.errorLabel isHidden];
}

- (void)displayError:(NSString *)errMsg
{
    [self.errorLabel setTitleWithMnemonic:errMsg];
    [self.errorView setHidden:NO];
    [self.startStopInfo setHidden:YES];
}

- (void)displayNoError
{
    [self.errorLabel setTitleWithMnemonic:@""];
    [self.errorView setHidden:YES];
    [self.startStopInfo setHidden:NO];
}

- (void)displayAutoStartupError:(NSString *)errMsg
{
    [self.autoStartupErrorLabel setTitleWithMnemonic:errMsg];
    [self.autoStartupErrorView setHidden:NO];
    [self.autoStartupInfo setHidden:YES];
}

- (void)displayAutoStartupNoError
{
    [self.autoStartupErrorLabel setTitleWithMnemonic:@""];
    [self.autoStartupErrorView setHidden:YES];
    [self.autoStartupInfo setHidden:NO];
}

- (void)displayUpdatingSettings
{
    [self.resetSettingsButton setEnabled:NO];
}

- (void)displayUpdatedSettings
{
    [self.resetSettingsButton setEnabled:YES];
}

- (IBAction)toggleAutoStartup:(id)sender
{
    [self postponeAuthorizationTimeout];
    if (!self.autoStartupChangedBySystem) {
        [self.delegate postgrePrefsDidClickAutoStartup:self];
    }
}

- (IBAction)startStopServer:(id)sender
{
    [self postponeAuthorizationTimeout];
    [self.delegate postgrePrefsDidClickStartStopServer:self];
}

- (IBAction)resetSettings:(id)sender
{
    [self postponeAuthorizationTimeout];
    [self.delegate postgrePrefsDidClickResetSettings:self];
}

- (IBAction)refreshButton:(id)sender
{
    [self postponeAuthorizationTimeout];
    [self.delegate postgrePrefsDidClickRefresh:self];
}
@end

//
//  Postgres.m
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import "PGPrefsPane.h"
#import "PGPrefsController.h"
#import "PGPrefsUtilities.h"

@implementation PostgrePrefs

@synthesize authView = _authView;
@synthesize unlockedView = _unlockedView;
@synthesize lockedView = _lockedView;
@synthesize settingsForm = _settingsForm;
@synthesize unlockedTabs = _unlockedTabs;
@synthesize startStopInfo = _startStopInfo;
@synthesize resetSettingsButton = _resetSettingsButton;
@synthesize statusImage = _statusImage;
@synthesize statusLabel = _statusLabel;
@synthesize statusInfo = _statusInfo;
@synthesize settingsUsername = _settingsUsername;
@synthesize settingsBinDir = _settingsBinDir;
@synthesize settingsDataDir = _settingsDataDir;
@synthesize settingsLogFile = _settingsLogFile;
@synthesize settingsPort = _settingsPort;
@synthesize startStopButton = _startStopButton;
@synthesize refreshButton = _refreshButton;
@synthesize spinner = _spinner;
@synthesize autoStartupCheckbox = _autoStartupCheckbox;
@synthesize autoStartupInfo = _autoStartupInfo;
@synthesize errorIcon = _errorIcon;
@synthesize errorLabel = _errorLabel;

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)val {
    delegate = val;
}

- (NSString *)username {
    return [self.settingsUsername stringValue];
}

- (void)setUsername:(NSString *)val {
    [self.settingsUsername setStringValue:val];
}

- (NSString *)binDirectory {
    return [self.settingsBinDir stringValue];
}

- (void)setBinDirectory:(NSString *)val {
    [self.settingsBinDir setStringValue:val];
}

- (NSString *)dataDirectory {
    return [self.settingsDataDir stringValue];
}

- (void)setDataDirectory:(NSString *)val {
    [self.settingsDataDir setStringValue:val];
}

- (NSString *)logFile {
    return [self.settingsLogFile stringValue];
}

- (void)setLogFile:(NSString *)val {
    [self.settingsLogFile setStringValue:val];
}

- (NSString *)port {
    return [self.settingsPort stringValue];
}

- (void)setPort:(NSString *)val {
    [self.settingsPort setStringValue:val];
}

- (BOOL)autoStartup {
    return [self.autoStartupCheckbox state] == NSOnState;
}

- (void)setAutoStartup:(BOOL)enabled {
    autoStartupChangedBySystem = YES;
    if( enabled  ) {
        [self.autoStartupCheckbox setState:NSOnState];
    } else {
        [self.autoStartupCheckbox setState:NSOffState];
    }
    autoStartupChangedBySystem = NO;
}

- (BOOL)isAuthorized {
    return [self.authView authorizationState] == SFAuthorizationViewUnlockedState;
}

- (AuthorizationRef)authorization {
    return [[self.authView authorization] authorizationRef];
}

- (void)initAuthorization {
    AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
    [self.authView setAuthorizationRights:&rights];
    self.authView.delegate = self;
    [self.authView updateStatus:nil];
    [self.authView setAutoupdate:YES];
}

- (void)destroyAuthorization {
    [self.authView deauthorize:[self.authView authorization]];
}

- (void)postponeAuthorizationTimeout {
    if ([self isAuthorized]) {
        // No good way to do this at present - this is just a stub function
        // in case a method presents itself in future.
    }
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
    [delegate postgrePrefsDidAuthorize:self];
    
    // Reset editing settings mode
    editingSettings = NO;    
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view {
    [delegate postgrePrefsDidDeauthorize:self];
    
    // Reset editing settings mode
    editingSettings = NO;    
}

- (BOOL)wasEditingSettings {
    return editingSettings;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    if ([tabView indexOfTabViewItem:tabViewItem] == 0) {
        if (editingSettings) {
            [self postponeAuthorizationTimeout];
            [delegate postgrePrefsDidFinishEditingSettings:self];
        }
        editingSettings = NO;
    } else {
        editingSettings = YES;        
    }
}

- (void)mainViewDidLoad {
    // Remove existing delegate
    if ([self delegate]) {
        DLog(@"Warning - delegate already exists! Removing existing delegate...");
        id existingDelegate = [self delegate];
        [self setDelegate:nil];
        [existingDelegate release];
    }
    
    // Set new delegate
    [self setDelegate:[[PostgrePrefsController alloc] init]];

    // Reset editing settings mode
    editingSettings = NO;

    // Listen for tab changes
    self.unlockedTabs.delegate = self;
    
    // Call delegate DidLoad method
    [delegate postgrePrefsDidLoad:self];
}

- (void)willUnselect {
    [delegate postgrePrefsWillUnselect:self];

    // Reset editing settings mode
    editingSettings = NO;
}

- (NSDictionary *)persistedPreferences {
    return [[NSUserDefaults standardUserDefaults] persistentDomainForName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
}

- (void)setPersistedPreferences:(NSDictionary *) prefs {
    // Remove existing prefs
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    
    // Save new prefs
    if (! isBlankDictionary(prefs)) {
        [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName: [[NSBundle bundleForClass:[self class]] bundleIdentifier]];
    }
}

- (NSDictionary *)guiPreferences {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [[self.settingsUsername stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"Username", 
            [[self.settingsBinDir stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"BinDirectory", 
            [[self.settingsDataDir stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"DataDirectory", 
            [[self.settingsLogFile stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"LogFile",
            [[self.settingsPort stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"Port",
            ([self.autoStartupCheckbox state] == NSOnState ? @"Yes" : @"No"), @"AutoStartup",
            nil];
}

- (void)setGuiPreference:(NSDictionary *)prefs key:(NSString *)key gui:(NSFormCell *)cell {
    
    // Clean key
    key = [key stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    
    // Get value from prefs - may not exist
    id value = [prefs objectForKey:key];
    
    // Value exists
    if (value && value != [NSNull null] && [value isKindOfClass:[NSString class]] && [value length] > 0) {
        
        [cell setStringValue:value];
        
    // No value - set blank
    } else {
        [cell setStringValue:@""];
    }
}

- (void)setGuiPreferences:(NSDictionary *) prefs defaults:(NSDictionary *) defaults {
    [self setGuiPreference:prefs key:@"Username" gui:self.settingsUsername];
    [self setGuiPreference:prefs key:@"BinDirectory" gui:self.settingsBinDir];
    [self setGuiPreference:prefs key:@"DataDirectory" gui:self.settingsDataDir];
    [self setGuiPreference:prefs key:@"LogFile" gui:self.settingsLogFile];
    [self setGuiPreference:prefs key:@"Port" gui:self.settingsPort];
    autoStartupChangedBySystem = YES;
    [self.autoStartupCheckbox setState:([[prefs objectForKey:@"AutoStartup"] isEqualToString:@"Yes"] || [[prefs objectForKey:@"AutoStartup"] isEqualToString:@"true"] ? NSOnState : NSOffState)];
    autoStartupChangedBySystem = NO;
}

- (void)setGuiPreferences:(NSDictionary *) prefs {
    [self setGuiPreferences:prefs defaults:nil];
}

- (void)displayStarted {
    NSString *startedPath = [[self bundle] pathForResource:@"started" ofType:@"png"];
    NSImage *started = [[NSImage alloc] initWithContentsOfFile:startedPath];
    
    [self.startStopButton setTitle:@"Stop PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The PostgreSQL Database Server is started and ready for client connections. To shut down the server, use the \"Stop PostgreSQL Server\" button."];
    [self.statusLabel setTitleWithMnemonic:@"Running"];
    [self.statusLabel setTextColor:[NSColor greenColor]];
    [self.startStopInfo setTitleWithMnemonic:@"If you stop the server, you and your applications will not be able to use PostgreSQL and all current connections will be closed."];
    [self.statusImage setImage:started];        
    
    [self.startStopButton setEnabled:YES];
    [self.refreshButton setEnabled:YES];
    [self.autoStartupCheckbox setEnabled:YES];
    [self.spinner stopAnimation:self];
    
    [started release];
}

- (void)displayStopped {
    NSString *stoppedPath = [[self bundle] pathForResource:@"stopped" ofType:@"png"];
    NSImage *stopped = [[NSImage alloc] initWithContentsOfFile:stoppedPath];
    
    [self.startStopButton setTitle:@"Start PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The PostgreSQL Database Server is currently stopped.\nTo start it, use the \"Start PostgreSQL Server\" button."];
    [self.statusLabel setTitleWithMnemonic:@"Stopped"];
    [self.statusLabel setTextColor:[NSColor redColor]];
    [self.startStopInfo setTitleWithMnemonic:@""];
    [self.statusImage setImage:stopped];
    
    [self.startStopButton setEnabled:YES];
    [self.refreshButton setEnabled:YES];
    [self.autoStartupCheckbox setEnabled:YES];
    [self.spinner stopAnimation:self];
    
    [stopped release];
}

- (void)displayStarting {
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    [self.statusLabel setTitleWithMnemonic:@"Starting..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.statusImage setImage:checking];
    [self.startStopButton setEnabled:NO];
    [self.refreshButton setEnabled:NO];
    [self.spinner startAnimation:self];
    [checking release];
}

- (void)displayStopping {
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    [self.statusLabel setTitleWithMnemonic:@"Stopping..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.statusImage setImage:checking];
    [self.startStopButton setEnabled:NO];
    [self.refreshButton setEnabled:NO];
    [self.spinner startAnimation:self];
    [checking release];
}

- (void)displayChecking {
    NSString *checkingPath = [[self bundle] pathForResource:@"checking" ofType:@"png"];
    NSImage *checking = [[NSImage alloc] initWithContentsOfFile:checkingPath];
    
    [self.startStopButton setTitle:@"PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The running status of the PostgreSQL Database Server is not currently known."];
    [self.statusLabel setTitleWithMnemonic:@"Checking..."];
    [self.statusLabel setTextColor:[NSColor blueColor]];
    [self.startStopInfo setTitleWithMnemonic:@""];
    [self.statusImage setImage:checking];
    
    [self.startStopButton setEnabled:NO];
    [self.refreshButton setEnabled:NO];
    [self.spinner startAnimation:self];
    
    [self displayAutoStartupNoError];
    [self.autoStartupCheckbox setEnabled:NO];
    
    [checking release];
}

- (void)displayUnknown {
    NSString *stoppedPath = [[self bundle] pathForResource:@"stopped" ofType:@"png"];
    NSImage *stopped = [[NSImage alloc] initWithContentsOfFile:stoppedPath];
    
    [self.startStopButton setTitle:@"PostgreSQL"];
    [self.statusInfo setTitleWithMnemonic:@"The running status of the PostgreSQL Database Server is not currently known."];
    [self.statusLabel setTitleWithMnemonic:@"Unknown"];
    [self.statusLabel setTextColor:[NSColor redColor]];
    [self.statusImage setImage:stopped];
    if (isBlankString([self.startStopInfo stringValue])) {
        [self.startStopInfo setTitleWithMnemonic:@"Please check the values in the Settings tab and try again."];
    }
    [self.startStopButton setEnabled:NO];
    [self.refreshButton setEnabled:YES];
    [self.spinner stopAnimation:self];
    
    [stopped release];
}

- (void)displayLocked {
    [self.unlockedView setHidden: ![self isAuthorized]];
    [self.lockedView setHidden: [self isAuthorized]];
}

- (void)displayUnlocked {
    [self.unlockedView setHidden: ![self isAuthorized]];
    [self.lockedView setHidden: [self isAuthorized]];
    [self.unlockedTabs selectTabViewItemAtIndex:0];
}

- (bool)isError {
    return ![self.errorLabel isHidden];
}

- (void)displayError:(NSString *)errMsg {
    [self.errorLabel setTitleWithMnemonic:errMsg];
    [self.errorLabel setHidden:NO];
    [self.errorIcon setHidden:NO];
    [self.startStopInfo setHidden:YES];
}

- (void)displayNoError {
    [self.errorLabel setTitleWithMnemonic:@""];
    [self.errorLabel setHidden:YES];
    [self.errorIcon setHidden:YES];
    [self.startStopInfo setHidden:NO];
}

- (void)displayAutoStartupError:(NSString *) errMsg {
    [self.autoStartupInfo setTextColor:[NSColor redColor]];
    [self.autoStartupInfo setTitleWithMnemonic:errMsg];
}

- (void)displayAutoStartupNoError {
    [self.autoStartupInfo setTextColor:[NSColor blackColor]];
    [self.autoStartupInfo setTitleWithMnemonic:@"Select this option if you would like the PostgreSQL server to start automatically whenever your computer starts up."];    
}

- (void)dealloc {
    [delegate release];
    [super dealloc];
}

- (void)displayUpdatingSettings {
    [self.resetSettingsButton setEnabled:NO];
}

- (void)displayUpdatedSettings {
    [self.resetSettingsButton setEnabled:YES];
}

- (IBAction)toggleAutoStartup:(id)sender {
    [self postponeAuthorizationTimeout];
    if (!autoStartupChangedBySystem) {
        [delegate postgrePrefsDidClickAutoStartup:self];
    }
}

- (IBAction)startStopServer:(id)sender {
    [self postponeAuthorizationTimeout];
    [delegate postgrePrefsDidClickStartStopServer:self];
}

- (IBAction)resetSettings:(id)sender {
    [self postponeAuthorizationTimeout];
    [delegate postgrePrefsDidClickResetSettings:self];
}

- (IBAction)refreshButton:(id)sender {
    [self postponeAuthorizationTimeout];
    [delegate postgrePrefsDidClickRefresh:self];
}
@end

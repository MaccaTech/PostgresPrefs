//
//  Postgres.h
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>

@interface PostgrePrefs : NSPreferencePane <NSTabViewDelegate> {
@private
    id delegate;
    BOOL autoStartupChangedBySystem;
    BOOL editingSettings;
}

- (id)delegate;
- (void)setDelegate:(id)val;

@property (weak) IBOutlet NSButton *resetSettingsButton;
@property (weak) IBOutlet NSImageView *statusImage;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSTextField *statusInfo;
@property (weak) IBOutlet NSTextField *startStopInfo;
@property (weak) IBOutlet NSButton *startStopButton;
@property (weak) IBOutlet NSButton *refreshButton;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSButton *autoStartupCheckbox;
@property (weak) IBOutlet NSTextField *autoStartupInfo;
@property (weak) IBOutlet NSTextField *errorLabel;
@property (weak) IBOutlet NSImageView *errorIcon;
@property (weak) IBOutlet SFAuthorizationView *authView;
@property (weak) IBOutlet NSView *unlockedView;
@property (weak) IBOutlet NSView *lockedView;
@property (weak) IBOutlet NSForm *settingsForm;
@property (weak) IBOutlet NSFormCell *settingsUsername;
@property (weak) IBOutlet NSFormCell *settingsBinDir;
@property (weak) IBOutlet NSFormCell *settingsDataDir;
@property (weak) IBOutlet NSFormCell *settingsLogFile;
@property (weak) IBOutlet NSFormCell *settingsPort;
@property (weak) IBOutlet NSTabView *unlockedTabs;

- (NSDictionary *)guiPreferences;
- (void)setGuiPreferences:(NSDictionary *) prefs;
- (NSDictionary *)persistedPreferences;
- (void)setPersistedPreferences:(NSDictionary *) prefs;

- (NSString *)username;
- (void)setUsername:(NSString *)val;
- (NSString *)binDirectory;
- (void)setBinDirectory:(NSString *)val;
- (NSString *)dataDirectory;
- (void)setDataDirectory:(NSString *)val;
- (NSString *)logFile;
- (void)setLogFile:(NSString *)val;
- (NSString *)port;
- (void)setPort:(NSString *)val;
- (BOOL)autoStartup;
- (void)setAutoStartup:(BOOL)enabled;

- (IBAction)startStopServer:(id)sender;
- (IBAction)refreshButton:(id)sender;
- (IBAction)toggleAutoStartup:(id)sender;
- (IBAction)resetSettings:(id)sender;

- (BOOL)wasEditingSettings;

- (void)initAuthorization;
- (void)destroyAuthorization;
- (BOOL)isAuthorized;
- (AuthorizationRef)authorization;

- (void)displayStarted;
- (void)displayStopped;
- (void)displayStarting;
- (void)displayStopping;
- (void)displayChecking;
- (void)displayUnknown;
- (void)displayLocked;
- (void)displayUnlocked;
- (void)displayError:(NSString *) errMsg;
- (void)displayNoError;
- (void)displayUpdatingSettings;
- (void)displayUpdatedSettings;
- (void)displayAutoStartupError:(NSString *) errMsg;
- (void)displayAutoStartupNoError;

@end


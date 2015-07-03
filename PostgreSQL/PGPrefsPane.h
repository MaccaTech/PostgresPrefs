//
//  Postgres.h
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>

@class PostgrePrefs;

@protocol PostgrePrefsDelegate <NSObject>
@required
- (void)postgrePrefsDidAuthorize:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidDeauthorize:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidLoad:(PostgrePrefs *) prefs;
- (void)postgrePrefsWillUnselect:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickStartStopServer:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickRefresh:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickAutoStartup:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickResetSettings:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidFinishEditingSettings:(PostgrePrefs *) prefs;
@optional
@end

@interface PostgrePrefs : NSPreferencePane <NSTabViewDelegate>

@property (nonatomic, readonly) BOOL autoStartupChangedBySystem;
@property (nonatomic, readonly) BOOL editingSettings;
@property (nonatomic, readonly) BOOL invalidSettings;
@property (nonatomic, readonly) BOOL canStartStop;
@property (nonatomic, readonly) BOOL canRefresh;
@property (nonatomic, readonly) BOOL canChangeAutoStartup;

@property (nonatomic, strong) id<PostgrePrefsDelegate> delegate;

@property (nonatomic, weak) IBOutlet SFAuthorizationView *authView;
@property (nonatomic, weak) IBOutlet NSTabView *authTabs;
@property (nonatomic, weak) IBOutlet NSTabView *mainTabs;
@property (nonatomic, weak) IBOutlet NSButton *resetSettingsButton;
@property (nonatomic, weak) IBOutlet NSImageView *statusImage;
@property (nonatomic, weak) IBOutlet NSTextField *statusLabel;
@property (nonatomic, weak) IBOutlet NSTextField *statusInfo;
@property (nonatomic, weak) IBOutlet NSTextField *startStopInfo;
@property (nonatomic, weak) IBOutlet NSButton *startStopButton;
@property (nonatomic, weak) IBOutlet NSButton *refreshButton;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *spinner;
@property (nonatomic, weak) IBOutlet NSButton *autoStartupCheckbox;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *autoStartupSpinner;
@property (nonatomic, weak) IBOutlet NSView *autoStartupErrorView;
@property (nonatomic, weak) IBOutlet NSTextField *autoStartupErrorLabel;
@property (nonatomic, weak) IBOutlet NSTextField *autoStartupInfo;
@property (nonatomic, weak) IBOutlet NSView *errorView;
@property (nonatomic, weak) IBOutlet NSTextField *errorLabel;
@property (nonatomic, weak) IBOutlet NSForm *settingsForm;
@property (nonatomic, weak) IBOutlet NSFormCell *settingsUsername;
@property (nonatomic, weak) IBOutlet NSFormCell *settingsBinDir;
@property (nonatomic, weak) IBOutlet NSFormCell *settingsDataDir;
@property (nonatomic, weak) IBOutlet NSFormCell *settingsLogFile;
@property (nonatomic, weak) IBOutlet NSFormCell *settingsPort;

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
- (void)displayWillChangeAutoStartup;
- (void)displayDidChangeAutoStartup;
- (void)displayError:(NSString *) errMsg;
- (void)displayNoError;
- (void)displayUpdatingSettings;
- (void)displayUpdatedSettings;
- (void)displayAutoStartupError:(NSString *) errMsg;
- (void)displayAutoStartupNoError;

@end


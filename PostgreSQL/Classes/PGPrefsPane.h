//
//  Postgres.h
//  Postgres
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "NSString+Utilities.h"
#import "NSDictionary+Utilities.h"

@class PGPrefsPane;

#pragma mark - Constants

extern NSString *const PGPrefsUsernameKey;
extern NSString *const PGPrefsBinDirectoryKey;
extern NSString *const PGPrefsDataDirectoryKey;
extern NSString *const PGPrefsLogFileKey;
extern NSString *const PGPrefsPortKey;
extern NSString *const PGPrefsAutoStartupKey;



#pragma mark - PGPrefsPaneDelegate

@protocol PGPrefsPaneDelegate <NSObject>
@required
- (void)postgrePrefsDidAuthorize:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidDeauthorize:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidLoad:(PGPrefsPane *)prefs;
- (void)postgrePrefsWillUnselect:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidClickStartStopServer:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidClickRefresh:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidClickAutoStartup:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidClickResetSettings:(PGPrefsPane *)prefs;
- (void)postgrePrefsDidFinishEditingSettings:(PGPrefsPane *)prefs;
@optional
// None
@end



#pragma mark - PGPrefsPane

@interface PGPrefsPane : NSPreferencePane <NSTabViewDelegate>

@property (nonatomic, strong) id<PGPrefsPaneDelegate> delegate;

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

@property (nonatomic, strong) NSDictionary *guiPreferences;
@property (nonatomic, strong) NSDictionary *savedPreferences;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *binDirectory;
@property (nonatomic, strong) NSString *dataDirectory;
@property (nonatomic, strong) NSString *logFile;
@property (nonatomic, strong) NSString *port;
@property (nonatomic) BOOL autoStartup;

- (IBAction)startStopServer:(id)sender;
- (IBAction)refreshButton:(id)sender;
- (IBAction)toggleAutoStartup:(id)sender;
- (IBAction)resetSettings:(id)sender;

- (BOOL)wasEditingSettings;

- (void)initAuthorization;
- (void)destroyAuthorization;
- (BOOL)authorized;
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
- (void)displayError:(NSString *)errMsg;
- (void)displayNoError;
- (void)displayUpdatingSettings;
- (void)displayUpdatedSettings;
- (void)displayAutoStartupError:(NSString *)errMsg;
- (void)displayAutoStartupNoError;

@end


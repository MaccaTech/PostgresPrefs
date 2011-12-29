//
//  PGPrefsPaneDelegate.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 26/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

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
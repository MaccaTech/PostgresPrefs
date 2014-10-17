//
//  PostgrePrefsDelegate.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 18/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGPrefsPane.h"

extern NSString * const LAUNCH_AGENT_PLIST_FILENAME;

@interface PostgrePrefsController: NSObject <PostgrePrefsDelegate> {
@private
    NSString *_status;
}

- (void)postgrePrefsDidAuthorize:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidDeauthorize:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidLoad:(PostgrePrefs *) prefs;
- (void)postgrePrefsWillUnselect:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickStartStopServer:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickRefresh:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickAutoStartup:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidClickResetSettings:(PostgrePrefs *) prefs;
- (void)postgrePrefsDidFinishEditingSettings:(PostgrePrefs *)prefs;

@end

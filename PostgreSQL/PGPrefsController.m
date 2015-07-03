//
//  PostgrePrefsDelegate.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 18/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import "PGPrefsController.h"
#import "PGPrefsUtilities.h"

NSString * const LAUNCH_AGENT_PLIST_FILENAME = @"/tmp/com.hkwebentrepreneurs.postgresql.plist";

@implementation PostgrePrefsController

- (NSString*)runShell:(PostgrePrefs *) prefs command:(NSArray *) command {
    return runCommand(@"/bin/bash", [@[@"-c"] arrayByAddingObjectsFromArray:command], YES);
}
- (void)runShellNoOutput:(PostgrePrefs *) prefs command:(NSArray *) command {
    runCommand(@"/bin/bash", [@[@"-c"] arrayByAddingObjectsFromArray:command], NO);
}
- (NSString*)runAuthorizedShell:(PostgrePrefs *) prefs command:(NSArray *) command {    
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
    return runAuthorizedCommand(@"/usr/bin/osascript", [@[path] arrayByAddingObjectsFromArray:command], [prefs authorization], YES);
}
- (void)runAuthorizedShellNoOutput:(PostgrePrefs *) prefs command:(NSArray *) command {
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
    runAuthorizedCommand(@"/usr/bin/osascript", [@[path] arrayByAddingObjectsFromArray:command], [prefs authorization], NO);
}

//
// Tries to find PostgreSQL installation and generate appropriate start/stop settings.
//
- (NSDictionary *)detectPostgreSQLInstallationAndGenerateSettings:(PostgrePrefs *) prefs {
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsDetectDefaults" ofType:@"sh"];
    NSString *pg_ctl = [self runAuthorizedShell:prefs command:@[path, [NSString stringWithFormat:@" --DEBUG=%@", (IsLogging ? @"Yes" : @"No") ]]];
    
    if (pg_ctl) {
        NSArray *lines = [pg_ctl componentsSeparatedByString:@"\n"];
        NSString *username = nil, *binDir = nil, *dataDir = nil, *logFile = nil, *port = nil, *autoStartup = nil;
        NSString *line;
        for (line in lines) {
            if ([line hasPrefix:@"PGUSER="]) {
                username = [[line substringFromIndex:[@"PGUSER=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([line hasPrefix:@"PGDATA="]) {
                dataDir = [[line substringFromIndex:[@"PGDATA=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([line hasPrefix:@"PGBIN="]) {
                binDir = [[line substringFromIndex:[@"PGBIN=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([line hasPrefix:@"PGLOG="]) {
                logFile = [[line substringFromIndex:[@"PGLOG=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([line hasPrefix:@"PGPORT="]) {
                port = [[line substringFromIndex:[@"PGPORT=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([line hasPrefix:@"PGAUTO="]) {
                autoStartup = [[line substringFromIndex:[@"PGAUTO=" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }
        return @{
            @"Username":username,
            @"BinDirectory":binDir,
            @"DataDirectory":dataDir,
            @"LogFile":logFile,
            @"Port":port,
            @"AutoStartup":autoStartup
        };
    } else {
        return nil;
    }
}

//
// Checks if start/stop/status command requires authorisation - i.e. needs to be run as admin
//
- (BOOL)postgreCommandRequiresAuthorisation:(PostgrePrefs *) prefs {
    NSString *currentUser = NSUserName();
    return isNonBlankString([prefs username]) && ![[currentUser lowercaseString] isEqualToString:[[prefs username] lowercaseString]];
}

//
// Generates the start/stop/status command
//
- (NSString *)generatePostgreCommand:(PostgrePrefs *) prefs command:(NSString *)command {
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsPostgreSQL" ofType:@"sh"];
    NSString *result = path;
    
    if (isNonBlankString([prefs username])) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGUSER=%@\"", [prefs username]]];
    }
    if (isNonBlankString([prefs dataDirectory])) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGDATA=%@\"", [prefs dataDirectory]]];
    }
    if (isNonBlankString([prefs port])) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGPORT=%@\"", [prefs port]]];
    }
    if (isNonBlankString([prefs binDirectory])) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGBIN=%@\"", [prefs binDirectory]]];
    }
    if (isNonBlankString([prefs logFile])) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGLOG=%@\"", [prefs logFile]]];
    }
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --PGAUTO=%@", ([prefs autoStartup] ? @"Yes" : @"No" ) ]];
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --DEBUG=%@", (IsLogging ? @"Yes" : @"No") ]];
    result = [result stringByAppendingString:[NSString stringWithFormat:@" %@", command]];
    
    return result;
}

//
// Runs 'pg_ctl status' to check if PostgreSQL is running and updates GUI with result
//
- (void)checkServerStatus:(PostgrePrefs *) prefs {
    _status = @"Unknown";
    @try {
        
        // Ensure not already deauthorised
        if ([prefs isAuthorized]) {
            
            NSString *command = [self generatePostgreCommand:prefs command:@"status"];
            NSString *result = nil;
            
            // One at a time
            @synchronized(self) {
                result = [self runAuthorizedShell:prefs command:@[command]];
            }
                
            DLog(@"PostgreSQL Status: %@", result);
            
            if (result) {
                if ([result rangeOfString:@"pg_ctl: server is running"].location != NSNotFound) {
                    _status = @"Started";
                } else if ([result rangeOfString:@"pg_ctl: no server running"].location != NSNotFound) {
                    _status = @"Stopped";
                } else {
                    [prefs displayError:result];
                }
            }
        }
        
    }
    @catch (NSException *err) {
        [prefs displayError:[NSString stringWithFormat:@"Error: %@\n%@", [err name], [err reason]]];
    }
    @finally {
        if ([_status isEqual:@"Started"]) {
            [prefs displayStarted];            
        } else if ([_status isEqual:@"Stopped"]) {
            [prefs displayStopped];
        } else {
            [prefs displayUnknown];
        }
    }    
}

//
// Runs 'pg_ctl start' and then checks server status
//
- (void)startServer:(PostgrePrefs *) prefs {
    [prefs displayStarting];
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if ([prefs isAuthorized]) {

            NSString *command = [self generatePostgreCommand:prefs command:@"start"];
            
            // One at a time
            @synchronized(self) {
                result = [self runAuthorizedShell:prefs command:@[command]];
            }
        }
        
    }
    @catch (NSException *err) {
        result = [NSString stringWithFormat:@"Error: %@\n%@", [err name], [err reason]];
    }
    @finally {        
        if (result) {
            [prefs displayError:result];
            [self checkServerStatus:prefs];
        } else {
            [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:3.0];
        }
    }    
}

//
// Runs 'pg_ctl stop' and then checks server status
//
- (void)stopServer:(PostgrePrefs *) prefs {
    [prefs displayStopping];
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if ([prefs isAuthorized]) {

            NSString *command = [self generatePostgreCommand:prefs command:@"stop"];
            
            // One at a time
            @synchronized(self) {
                result = [self runAuthorizedShell:prefs command:@[command]];
            }
        }
        
    }
    @catch (NSException *err) {
        result = [NSString stringWithFormat:@"Error: %@\n%@", [err name], [err reason]];
    }
    @finally {        
        if (result) {
            [prefs displayError:result];
            [self checkServerStatus:prefs];
        } else {
            [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:3.0];
        }
    }    
}

//
// On first startup - prepares for authorization, displays splash screen
//
- (void)postgrePrefsDidLoad:(PostgrePrefs *)prefs {
    DLog(@"Loaded");
    // Display splash screen
    [prefs initAuthorization];
    [prefs displayLocked];
}

//
// User finished authorization - gets settings, displays 'Start & Stop' tab and checks server status
//
- (void)postgrePrefsDidAuthorize:(PostgrePrefs *)prefs {
    DLog(@"Authorized");
    [prefs displayChecking];
    [prefs displayUnlocked];
    [prefs displayNoError];
    
    // Retrieve persisted settings and update in gui
    NSDictionary *settings = [prefs persistedPreferences];
    NSDictionary *defaults = nil;
    DLog(@"Saved Settings: %@", settings);
    
    // Only generate defaults if we have no persisted settings
    if (isBlankDictionary(settings)) {
        defaults = [self detectPostgreSQLInstallationAndGenerateSettings:prefs];
        DLog(@"Default Settings: %@", defaults);
    }
    NSDictionary *combined = mergeDictionaries(settings, defaults);
    DLog(@"Combined Settings: %@", combined);
    [prefs setGuiPreferences:combined];
    
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:0.5];
}

//
// DidDauthorize method will be called in any of following situations:
// 1. User clicked to close lock
// 2. User clicked show all
// 3. Sometimes called after PrefsDidLoad! <-- IMPORTANT
//
- (void)postgrePrefsDidDeauthorize:(PostgrePrefs *)prefs {
    DLog(@"Deauthorized");
    [prefs displayLocked];
    if ([prefs wasEditingSettings]) {
        [prefs setPersistedPreferences:[prefs guiPreferences]];
    }
}

//
// User clicked 'Show All' or quit - deletes authorization, displays splash screen
//
- (void)postgrePrefsWillUnselect:(PostgrePrefs *)prefs {
    DLog(@"Unselected");
    [prefs destroyAuthorization]; // This will trigger call to DidDeauthorise
    [prefs displayLocked];
}

//
// User clicked button to start/stop server - calls start/stop command
//
- (void)postgrePrefsDidClickStartStopServer:(PostgrePrefs *)prefs {
    if ([_status isEqualToString:@"Started"]) {
        [prefs displayStopping];
        [self performSelector:@selector(stopServer:) withObject:prefs afterDelay:0.2];
    } else {
        [prefs displayStarting];
        [self performSelector:@selector(startServer:) withObject:prefs afterDelay:0.2];
    }    
}

//
// Adds or removes postgresql launch agent in launchctl
//
- (BOOL)setPostgreLaunchAgent:(PostgrePrefs *) prefs enabled:(BOOL)enabled {
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if ([prefs isAuthorized]) {
            
            NSString *command = [self generatePostgreCommand:prefs command:(enabled ? @"AutoOn" : @"AutoOff")];
            
            // One at a time
            @synchronized(self) {
                result = [self runAuthorizedShell:prefs command:@[command]];
            }
        }
        return YES;        
    }
    @catch (NSException *err) {
        result = [NSString stringWithFormat:@"Error: %@\n%@", [err name], [err reason]];
    }
    @finally {
        if (result) {
            [prefs displayAutoStartupError:result];
            return NO;
        } else {
            return YES;
        }
    }
}

//
// Apply auto-startup - adds/removes launchagent, and if fails then reverts GUI
//
- (void)applyAutoStartup:(PostgrePrefs *) prefs {
    [prefs displayNoError];
    [prefs displayAutoStartupNoError];
    if( [prefs autoStartup]  ) {
        if(![self setPostgreLaunchAgent:prefs enabled:YES]) {
            [prefs setAutoStartup:NO];
        }
    } else {
        [self setPostgreLaunchAgent:prefs enabled:NO];
        [prefs setAutoStartup:NO];
    }
    [prefs setPersistedPreferences:[prefs guiPreferences]];
}

//
// Apply auto-startup and trigger check status afterwards
//
- (void)applyAutoStartupAndCheckStatus:(PostgrePrefs *) prefs {
    [self applyAutoStartup:prefs];
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:3.0];
}

//
// Apply auto-startup and re-enable checkbox
//
- (void)applyAutoStartupAndNotifyCompleted:(PostgrePrefs *) prefs {
    [self applyAutoStartup:prefs];
    [prefs displayDidChangeAutoStartup];
}

//
// Settings updated - displays checking, saves prefs, updates launchctl & checks server status
//
- (void)applyUpdatedSettings:(PostgrePrefs *) prefs {
    [prefs displayChecking];
    [prefs setPersistedPreferences:[prefs guiPreferences]];
    [self performSelector:@selector(applyAutoStartupAndCheckStatus:) withObject:prefs afterDelay:0.2];
}

//
// User changed auto-startup
//
- (void)postgrePrefsDidClickAutoStartup:(PostgrePrefs *) prefs {
    [prefs displayWillChangeAutoStartup];
    [self performSelectorInBackground:@selector(applyAutoStartupAndNotifyCompleted:) withObject:prefs];
}

//
// Check server status
//
- (void)refresh:(PostgrePrefs *) prefs {
    [prefs displayNoError];
    [prefs displayAutoStartupNoError];
    [prefs displayChecking];
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:2.0];    
}

//
// User clicked refresh
//
- (void)postgrePrefsDidClickRefresh:(PostgrePrefs *) prefs {
    [self refresh:prefs];
}

//
// User changed some settings - checks server status using new settings
//
- (void)postgrePrefsDidFinishEditingSettings:(PostgrePrefs *)prefs {
    if ([prefs isAuthorized]) {
        if (! isEqualStringDictionary([prefs guiPreferences], [prefs persistedPreferences]) ) {
            DLog(@"Changed Settings");
            [self applyUpdatedSettings:prefs];
        } else {
            [self refresh:prefs];            
        }
    }
}

//
// User clicked to reset settings to defaults
//
- (void)postgrePrefsDidClickResetSettings:(PostgrePrefs *) prefs {
    [prefs displayUpdatingSettings];
    NSDictionary *defaults = [self detectPostgreSQLInstallationAndGenerateSettings:prefs];
    DLog(@"Settings: %@", defaults);
    [prefs setGuiPreferences:defaults];
    [prefs setPersistedPreferences:nil];
    [prefs displayUpdatedSettings];
}

@end

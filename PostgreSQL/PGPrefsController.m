//
//  PostgrePrefsDelegate.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 18/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import "PGPrefsController.h"

#pragma mark - Interfaces

@interface PGPrefsController()
@property (nonatomic, readwrite) PGPrefsStatus status;
@end



#pragma mark - PGPrefsController

@implementation PGPrefsController

- (NSString*)runShell:(PGPrefsPane *)prefs command:(NSArray *)command
{
    return [@"/bin/bash" runWithArgs:[@[@"-c"] arrayByAddingObjectsFromArray:command]];
}
- (void)runShellNoOutput:(PGPrefsPane *)prefs command:(NSArray *)command
{
    [@"/bin/bash" startWithArgs:[@[@"-c"] arrayByAddingObjectsFromArray:command]];
}
- (NSString*)runAuthorizedShell:(PGPrefsPane *)prefs command:(NSArray *)command
{
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
    return [@"/usr/bin/osascript" runWithArgs:[@[path] arrayByAddingObjectsFromArray:command] authorization:prefs.authorization];
}
- (void)runAuthorizedShellNoOutput:(PGPrefsPane *)prefs command:(NSArray *)command
{
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsRunAsAdmin" ofType:@"scpt"];
    [@"/usr/bin/osascript" startWithArgs:[@[path] arrayByAddingObjectsFromArray:command] authorization:prefs.authorization];
}

//
// Tries to find PostgreSQL installation and generate appropriate start/stop settings.
//
- (NSDictionary *)detectPostgreSQLInstallationAndGenerateSettings:(PGPrefsPane *)prefs
{
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsDetectDefaults" ofType:@"sh"];
    NSString *pg_ctl = [self runAuthorizedShell:prefs command:@[path, [NSString stringWithFormat:@" --DEBUG=%@", (IsLogging ? @"Yes" : @"No") ]]];
    
    if (pg_ctl) {
        NSArray *lines = [pg_ctl componentsSeparatedByString:@"\n"];
        NSString *username = nil, *binDir = nil, *dataDir = nil, *logFile = nil, *port = nil, *autoStartup = nil;
        NSString *line;
        for (line in lines) {
            if ([line hasPrefix:@"PGUSER="]) {
                username = [[line substringFromIndex:[@"PGUSER=" length]] trimToNil]?:@"";
            } else if ([line hasPrefix:@"PGDATA="]) {
                dataDir = [[line substringFromIndex:[@"PGDATA=" length]] trimToNil]?:@"";
            } else if ([line hasPrefix:@"PGBIN="]) {
                binDir = [[line substringFromIndex:[@"PGBIN=" length]] trimToNil]?:@"";
            } else if ([line hasPrefix:@"PGLOG="]) {
                logFile = [[line substringFromIndex:[@"PGLOG=" length]] trimToNil]?:@"";
            } else if ([line hasPrefix:@"PGPORT="]) {
                port = [[line substringFromIndex:[@"PGPORT=" length]] trimToNil]?:@"";
            } else if ([line hasPrefix:@"PGAUTO="]) {
                autoStartup = [[line substringFromIndex:[@"PGAUTO=" length]] trimToNil]?:@"";
            }
        }
        return @{
            PGPrefsUsernameKey:username,
            PGPrefsBinDirectoryKey:binDir,
            PGPrefsDataDirectoryKey:dataDir,
            PGPrefsLogFileKey:logFile,
            PGPrefsPortKey:port,
            PGPrefsAutoStartupKey:autoStartup
        };
    } else {
        return nil;
    }
}

//
// Checks if start/stop/status command requires authorisation - i.e. needs to be run as admin
//
- (BOOL)postgreCommandRequiresAuthorisation:(PGPrefsPane *)prefs
{
    NSString *currentUser = NSUserName();
    return prefs.username.nonBlank && ![[currentUser lowercaseString] isEqualToString:[[prefs username] lowercaseString]];
}

//
// Generates the start/stop/status command
//
- (NSString *)generatePostgreCommand:(PGPrefsPane *)prefs command:(NSString *)command
{
    NSString *path = [[prefs bundle] pathForResource:@"PGPrefsPostgreSQL" ofType:@"sh"];
    NSString *result = path;
    
    if (prefs.username.nonBlank) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGUSER=%@\"", prefs.username]];
    }
    if (prefs.dataDirectory.nonBlank) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGDATA=%@\"", prefs.dataDirectory]];
    }
    if (prefs.port.nonBlank) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGPORT=%@\"", prefs.port]];
    }
    if (prefs.binDirectory.nonBlank) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGBIN=%@\"", prefs.binDirectory]];
    }
    if (prefs.logFile.nonBlank) {
        result = [result stringByAppendingString:[NSString stringWithFormat:@" \"--PGLOG=%@\"", prefs.logFile]];
    }
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --PGAUTO=%@", (prefs.autoStartup ? @"Yes" : @"No" ) ]];
    result = [result stringByAppendingString:[NSString stringWithFormat:@" --DEBUG=%@", (IsLogging ? @"Yes" : @"No") ]];
    result = [result stringByAppendingString:[NSString stringWithFormat:@" %@", command]];
    
    return result;
}

//
// Runs 'pg_ctl status' to check if PostgreSQL is running and updates GUI with result
//
- (void)checkServerStatus:(PGPrefsPane *)prefs
{
    self.status = PGPrefsStatusUnknown;
    @try {
        
        // Ensure not already deauthorised
        if (prefs.authorized) {
            
            NSString *command = [self generatePostgreCommand:prefs command:@"status"];
            NSString *result = nil;
            
            // One at a time
            @synchronized(self) {
                result = [self runAuthorizedShell:prefs command:@[command]];
            }
                
            DLog(@"PostgreSQL Status: %@", result);
            
            if (result) {
                if ([result rangeOfString:@"pg_ctl: server is running"].location != NSNotFound) {
                    self.status = PGPrefsStarted;
                } else if ([result rangeOfString:@"pg_ctl: no server running"].location != NSNotFound) {
                    self.status = PGPrefsStopped;
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
        switch (self.status) {
            case PGPrefsStarted:
                [prefs displayStarted];
                break;
            case PGPrefsStopped:
                [prefs displayStopped];
                break;
            default:
                [prefs displayUnknown];
        }
    }
}

//
// Runs 'pg_ctl start' and then checks server status
//
- (void)startServer:(PGPrefsPane *)prefs
{
    [prefs displayStarting];
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if (prefs.authorized) {

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
- (void)stopServer:(PGPrefsPane *)prefs
{
    [prefs displayStopping];
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if (prefs.authorized) {

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
- (void)postgrePrefsDidLoad:(PGPrefsPane *)prefs
{
    DLog(@"Loaded");
    // Display splash screen
    [prefs initAuthorization];
    [prefs displayLocked];
}

//
// User finished authorization - gets settings, displays 'Start & Stop' tab and checks server status
//
- (void)postgrePrefsDidAuthorize:(PGPrefsPane *)prefs
{
    DLog(@"Authorized");
    [prefs displayChecking];
    [prefs displayUnlocked];
    [prefs displayNoError];
    
    // Retrieve persisted settings
    NSDictionary *settings = prefs.savedPreferences;
    DLog(@"Saved Settings: %@", settings);
    
    // Only detect defaults if we have no persisted settings
    if (! settings.nonBlank) {
        settings = [self detectPostgreSQLInstallationAndGenerateSettings:prefs];
        DLog(@"Default Settings: %@", settings);
        
        // Save the settings
        prefs.savedPreferences = settings;
    }
    
    // Update in gui
    prefs.guiPreferences = settings;
    
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:0.5];
}

//
// DidDauthorize method will be called in any of following situations:
// 1. User clicked to close lock
// 2. User clicked show all
// 3. Sometimes called after PrefsDidLoad! <-- IMPORTANT
//
- (void)postgrePrefsDidDeauthorize:(PGPrefsPane *)prefs {
    DLog(@"Deauthorized");
    [prefs displayLocked];
    if (prefs.wasEditingSettings) prefs.savedPreferences = prefs.guiPreferences;
}

//
// User clicked 'Show All' or quit - deletes authorization, displays splash screen
//
- (void)postgrePrefsWillUnselect:(PGPrefsPane *)prefs
{
    DLog(@"Unselected");
    [prefs destroyAuthorization]; // This will trigger call to DidDeauthorise
    [prefs displayLocked];
}

//
// User clicked button to start/stop server - calls start/stop command
//
- (void)postgrePrefsDidClickStartStopServer:(PGPrefsPane *)prefs
{
    if (self.status == PGPrefsStarted) {
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
- (BOOL)setPostgreLaunchAgent:(PGPrefsPane *)prefs enabled:(BOOL)enabled
{
    NSString *result = nil;
    @try {
        
        // Ensure not already deauthorised
        if (prefs.authorized) {
            
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
- (void)applyAutoStartup:(PGPrefsPane *)prefs
{
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
    prefs.savedPreferences = prefs.guiPreferences;
}

//
// Apply auto-startup and trigger check status afterwards
//
- (void)applyAutoStartupAndCheckStatus:(PGPrefsPane *)prefs
{
    [self applyAutoStartup:prefs];
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:3.0];
}

//
// Apply auto-startup and re-enable checkbox
//
- (void)applyAutoStartupAndNotifyCompleted:(PGPrefsPane *)prefs
{
    [self applyAutoStartup:prefs];
    [prefs displayDidChangeAutoStartup];
}

//
// Settings updated - displays checking, saves prefs, updates launchctl & checks server status
//
- (void)applyUpdatedSettings:(PGPrefsPane *)prefs
{
    [prefs displayChecking];
    prefs.savedPreferences = prefs.guiPreferences;
    [self performSelector:@selector(applyAutoStartupAndCheckStatus:) withObject:prefs afterDelay:0.2];
}

//
// User changed auto-startup
//
- (void)postgrePrefsDidClickAutoStartup:(PGPrefsPane *)prefs
{
    [prefs displayWillChangeAutoStartup];
    [self performSelectorInBackground:@selector(applyAutoStartupAndNotifyCompleted:) withObject:prefs];
}

//
// Check server status
//
- (void)refresh:(PGPrefsPane *)prefs
{
    [prefs displayNoError];
    [prefs displayAutoStartupNoError];
    [prefs displayChecking];
    [self performSelector:@selector(checkServerStatus:) withObject:prefs afterDelay:2.0];    
}

//
// User clicked refresh
//
- (void)postgrePrefsDidClickRefresh:(PGPrefsPane *)prefs
{
    [self refresh:prefs];
}

//
// User changed some settings - checks server status using new settings
//
- (void)postgrePrefsDidFinishEditingSettings:(PGPrefsPane *)prefs
{
    if (prefs.authorized) {
        
        NSDictionary *guiPrefs = prefs.guiPreferences;
        NSDictionary *savedPrefs = prefs.savedPreferences;
        
        BOOL unchanged = (!guiPrefs && !savedPrefs) || [guiPrefs isEqualToDictionary:savedPrefs];
        if (unchanged) {
            [self refresh:prefs];
        } else {
            DLog(@"Changed Settings");
            [self applyUpdatedSettings:prefs];
        }
    }
}

//
// User clicked to reset settings to defaults
//
- (void)postgrePrefsDidClickResetSettings:(PGPrefsPane *)prefs
{
    [prefs displayUpdatingSettings];
    NSDictionary *defaults = [self detectPostgreSQLInstallationAndGenerateSettings:prefs];
    DLog(@"Settings: %@", defaults);
    prefs.guiPreferences = defaults;
    prefs.savedPreferences = nil;
    [prefs displayUpdatedSettings];
}

@end

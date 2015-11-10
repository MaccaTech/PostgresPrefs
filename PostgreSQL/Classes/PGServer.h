//
//  PGServer.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 5/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - Constants/Utilities

/// Default name for newly-created PGServer
extern NSString *const PGServerDefaultName;

extern NSString *const PGServerNameKey;
extern NSString *const PGServerDomainKey;
extern NSString *const PGServerUsernameKey;
extern NSString *const PGServerBinDirectoryKey;
extern NSString *const PGServerDataDirectoryKey;
extern NSString *const PGServerLogFileKey;
extern NSString *const PGServerPortKey;
extern NSString *const PGServerStartupKey;

extern NSString *const PGServerStatusUnknownName;
extern NSString *const PGServerStartingName;
extern NSString *const PGServerStartedName;
extern NSString *const PGServerStoppingName;
extern NSString *const PGServerStoppedName;
extern NSString *const PGServerDeletingName;
extern NSString *const PGServerRetryingName;
extern NSString *const PGServerUpdatingName;

extern NSString *const PGServerStartupManualName;
extern NSString *const PGServerStartupAtBootName;
extern NSString *const PGServerStartupAtLoginName;

typedef NS_ENUM(NSInteger, PGServerStartup) {
    PGServerStartupManual = 0,
    PGServerStartupAtBoot,
    PGServerStartupAtLogin
};

typedef NS_ENUM(NSInteger, PGServerStatus) {
    PGServerStatusUnknown = 0,
    PGServerStarting,
    PGServerStarted,
    PGServerStopping,
    PGServerStopped,
    PGServerDeleting,
    PGServerRetrying,
    PGServerUpdating
};

CG_INLINE NSString *
ServerStatusDescription(PGServerStatus value)
{
    switch (value) {
        case PGServerStatusUnknown: return PGServerStatusUnknownName;
        case PGServerStarting: return PGServerStartingName;
        case PGServerStarted: return PGServerStartedName;
        case PGServerStopping: return PGServerStoppingName;
        case PGServerStopped: return PGServerStoppedName;
        case PGServerDeleting: return PGServerDeletingName;
        case PGServerRetrying: return PGServerRetryingName;
        case PGServerUpdating: return PGServerUpdatingName;
    }
}

CG_INLINE PGServerStartup
ToServerStartup(id value)
{
    // Nil
    if (value == nil || value == [NSNull null]) return PGServerStartupManual;
    
    // Number
    if ([value isKindOfClass:[NSNumber class]]) return [((NSNumber *) value) integerValue];
    
    // String
    NSString *description = [[value description] lowercaseString];
    if ([description isEqualToString:[PGServerStartupAtBootName lowercaseString]]) return PGServerStartupAtBoot;
    else if ([description isEqualToString:[PGServerStartupAtLoginName lowercaseString]]) return PGServerStartupAtLogin;
    else return PGServerStartupManual;
}

CG_INLINE NSString *
ServerStartupDescription(PGServerStartup value)
{
    switch (value) {
        case PGServerStartupAtBoot: return PGServerStartupAtBootName;
        case PGServerStartupAtLogin: return PGServerStartupAtLoginName;
        default: return PGServerStartupManualName;
    }
}



#pragma mark - PGServerSettings

/**
 * The bare configuration settings for a Postgre Server.
 */
@interface PGServerSettings : NSObject

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *binDirectory;
@property (nonatomic, strong) NSString *dataDirectory;
@property (nonatomic, strong) NSString *logFile;
@property (nonatomic, strong) NSString *port;
@property (nonatomic) PGServerStartup startup;

- (id)initWithUsername:(NSString *)username binDirectory:(NSString *)binDirectory dataDirectory:(NSString *)dataDirectory logFile:(NSString *)logFile port:(NSString *)port startup:(PGServerStartup)startup;
- (id)initWithSettings:(PGServerSettings *)settings;

- (BOOL)isEqualToSettings:(PGServerSettings *)settings;

/// If YES, the username is different to the current user
- (BOOL)hasDifferentUser;

/// All fields are valid
- (BOOL)valid;
/// Flag all fields as valid
- (void)setValid;

// Invalid descriptions
@property (nonatomic) NSString *invalidUsername;
@property (nonatomic) NSString *invalidBinDirectory;
@property (nonatomic) NSString *invalidDataDirectory;
@property (nonatomic) NSString *invalidLogFile;
@property (nonatomic) NSString *invalidPort;

/**
 * Overrides all values from other settings.
 */
- (void)importAllSettings:(PGServerSettings *)settings;

/**
 * Returns a new settings initialised with the specified settings.
 */
+ (PGServerSettings *)settingsWithSettings:(PGServerSettings *)settings;

@end



#pragma mark - PGServer

/**
 * A Postgre Server, that has a unique name, configuration settings and current status
 * (including error message if there are problems).
 *
 * Additional properties include 'needsAuthorization' indicating if the Postgre Server
 * actions need to be run as root, and 'dirtySettings' which are settings that have not
 * yet been saved.
 */
@interface PGServer : NSObject

/// A unique runtime ID for the server. Not preserved between application launches.
@property (nonatomic, strong, readonly) NSString *uid;

/// The name of the server must be unique, as it will be used as part of the name of the server's configuration file
@property (nonatomic, strong) NSString *name;

/// The domain of the server, e.g. org.postgresql.preferences
@property (nonatomic, strong) NSString *domain;

/// This server's active settings - always non-nil
@property (nonatomic, strong) PGServerSettings *settings;

/// This server's dirty settings - always non-nil
@property (nonatomic, strong) PGServerSettings *dirtySettings;

/// If YES, this server's dirty settings are different to the active settings
@property (nonatomic) BOOL dirty;

/// The current status of the server
@property (nonatomic) PGServerStatus status;

/// The PID of the server's process, if running
@property (nonatomic) NSInteger pid;

/// If YES, this server is starting or stopping
@property (nonatomic) BOOL processing;

/// If YES, this server is started or retrying
@property (nonatomic, readonly) BOOL started;

/// Any error that has been thrown when carrying out a server action
@property (nonatomic, strong) NSString *error;

/// For external servers, the name without the domain. For internal servers, same as name.
@property (nonatomic, strong) NSString *shortName;

/// The fully-qualified name of the server
@property (nonatomic, strong) NSString *daemonName;

/// If YES, then the server should be loaded in the launchd root context.
/// For Internal servers, YES if it has a different username or requires startup-at-boot
/// For External servers, YES if it was previously loaded in the root context
@property (nonatomic, readonly) BOOL daemonForAllUsers;

/// If YES, the daemon was previously loaded in the launchd root context.
@property (nonatomic) BOOL daemonLoadedForAllUsers;

/// The daemon .plist file used to start the server using launchd
@property (nonatomic, strong, readonly) NSString *daemonFile;

/// If YES, the daemon file exists
@property (nonatomic, readonly) BOOL daemonFileExists;

/// The daemon .plist file for all users with auto-startup at boot
@property (nonatomic, readonly) NSString *daemonFileForAllUsersAtBoot;

/// The daemon .plist file for all users with auto-startup at login
@property (nonatomic, readonly) NSString *daemonFileForAllUsersAtLogin;

/// The daemon .plist file for the current user only
@property (nonatomic, readonly) NSString *daemonFileForCurrentUserOnly;

/// The daemon's log file for stdout & stderr
@property (nonatomic, strong, readonly) NSString *daemonLog;

/// If YES, the daemon log file exists
@property (nonatomic, readonly) BOOL daemonLogExists;

/// If NO, then this server is read-only - i.e. created outside of this tool
@property (nonatomic, readonly) BOOL editable;

/// If NO, then this server cannot be started/stopped
@property (nonatomic, readonly) BOOL actionable;

/// If NO, then this server should not be saved (because it's external)
@property (nonatomic, readonly) BOOL saveable;

/// If YES, server's daemon file is owned by another piece of software
@property (nonatomic) BOOL external;

/// Used for importing and exporting server properties in a standard dictionary format.
@property (nonatomic, strong) NSDictionary *properties;

/**
 * Used when user clicks Add New Server.
 *
 * Just creates a server with all blank settings.
 */
- (id)initWithName:(NSString *)name domain:(NSString *)domain;

/**
 * Used when creating a server from search results.
 *
 * The settings are manually constructed according to the type of search results.
 */
- (id)initWithName:(NSString *)name domain:(NSString *)domain settings:(PGServerSettings *)settings;

/**
 * @return YES if properties contains all required keys
 */
+ (BOOL)hasAllKeys:(NSDictionary *)properties;

@end

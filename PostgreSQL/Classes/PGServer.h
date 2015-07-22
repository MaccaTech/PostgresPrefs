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
        case PGServerStopped:return PGServerStoppedName;
        case PGServerRetrying:return PGServerRetryingName;
        case PGServerUpdating:return PGServerUpdatingName;
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



@class PGServer;

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
@property (nonatomic, strong) NSDictionary *properties;

- (id)initWithUsername:(NSString *)username binDirectory:(NSString *)binDirectory dataDirectory:(NSString *)dataDirectory logFile:(NSString *)logFile port:(NSString *)port startup:(PGServerStartup)startup;
- (id)initWithSettings:(PGServerSettings *)settings;
- (id)initWithProperties:(NSDictionary *)properties;
- (BOOL)isEqualToSettings:(PGServerSettings *)settings;

/// If YES, the username is different to the current user
- (BOOL)hasDifferentUser;

- (BOOL)valid;
- (void)setValid;
@property (nonatomic) BOOL invalidUsername;
@property (nonatomic) BOOL invalidBinDirectory;
@property (nonatomic) BOOL invalidDataDirectory;
@property (nonatomic) BOOL invalidLogFile;
@property (nonatomic) BOOL invalidPort;

/**
 * @return YES if properties contains all PGServerSettings keys
 */
+ (BOOL)containsServerSettings:(NSDictionary *)properties;

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

/// The name of the server must be unique, as it will be used as part of the name of the server's configuration file
@property (nonatomic, strong) NSString *name;

/// The domain of the server, e.g. org.postgresql.preferences
@property (nonatomic, strong) NSString *domain;

/// The full name of the server, equal to ${domain}.${name}
@property (nonatomic, strong, readonly) NSString *fullName;

/// This server's current settings, which may have been changed in the GUI but not yet saved
@property (nonatomic, strong) PGServerSettings *dirtySettings;

/// This server's active settings (i.e. those that have been saved somewhere)
@property (nonatomic, strong) PGServerSettings *settings;

/// If NO, the server cannot be started at login, only at boot. This is the case when the username is different to the current user.
@property (nonatomic, readonly) BOOL canStartAtLogin;

/// If YES, then the server is loaded into the root launchd context, so "check status" commands must be run as root. A server needs authorization if: (1) it has a different username or (2) it is run on boot
@property (nonatomic, readonly) BOOL needsAuthorization;

/// The current status of the server
@property (nonatomic) PGServerStatus status;

/// If YES, this server is starting or stopping
@property (nonatomic) BOOL processing;

/// Any error that has been thrown when carrying out a server action
@property (nonatomic, strong) NSString *error;

/// The server's log file
@property (nonatomic, strong) NSString *log;

/// If YES, the log file exists
@property (nonatomic, readonly) BOOL logExists;

- (id)initWithName:(NSString *)name domain:(NSString *)domain;
- (id)initWithName:(NSString *)name domain:(NSString *)domain settings:(PGServerSettings *)settings;

@end

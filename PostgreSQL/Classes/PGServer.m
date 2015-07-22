//
//  PGServer.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 5/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGServer.h"

#pragma mark - Constants

NSString *const PGServerDefaultName            = @"PostgreSQL";

NSString *const PGServerNameKey                = @"Name";
NSString *const PGServerUsernameKey            = @"Username";
NSString *const PGServerBinDirectoryKey        = @"BinDirectory";
NSString *const PGServerDataDirectoryKey       = @"DataDirectory";
NSString *const PGServerLogFileKey             = @"LogFile";
NSString *const PGServerPortKey                = @"Port";
NSString *const PGServerStartupKey             = @"Startup";

NSString *const PGServerStatusUnknownName      = @"Unknown";
NSString *const PGServerStartingName           = @"Starting";
NSString *const PGServerStartedName            = @"Started";
NSString *const PGServerStoppingName           = @"Stopping";
NSString *const PGServerStoppedName            = @"Stopped";
NSString *const PGServerRetryingName           = @"Retrying";
NSString *const PGServerUpdatingName           = @"Updating";

NSString *const PGServerStartupManualName      = @"Manual";
NSString *const PGServerStartupAtBootName      = @"Boot";
NSString *const PGServerStartupAtLoginName     = @"Login";



#pragma mark - Interfaces

@interface PGServerSettings()
@property (nonatomic, strong) NSMutableSet *invalidProperties;
@end



#pragma mark - PGServerSettings

@implementation PGServerSettings

- (id)initWithUsername:(NSString *)username binDirectory:(NSString *)binDirectory dataDirectory:(NSString *)dataDirectory logFile:(NSString *)logFile port:(NSString *)port startup:(PGServerStartup)startup
{
    self = [super init];
    if (self) {
        self.username = username;
        self.binDirectory = binDirectory;
        self.dataDirectory = dataDirectory;
        self.logFile = logFile;
        self.port = port;
        self.startup = startup;
    }
    return self;
}
- (id)initWithSettings:(PGServerSettings *)settings
{
    return [self initWithUsername:settings.username binDirectory:settings.binDirectory dataDirectory:settings.dataDirectory logFile:settings.logFile port:settings.port startup:settings.startup];
}
- (id)initWithProperties:(NSDictionary *)properties
{
    self = [super init];
    if (self) {
        self.properties = properties;
    }
    return self;
}
- (BOOL)isEqualToSettings:(PGServerSettings *)settings
{
    if (self == settings) return YES;
    if (!settings) return NO;
    if (!self.username && settings.username) return NO;
    if (self.username && ![self.username isEqualToString:settings.username]) return NO;
    if (!self.binDirectory && settings.binDirectory) return NO;
    if (self.binDirectory && ![self.binDirectory isEqualToString:settings.binDirectory]) return NO;
    if (!self.dataDirectory && settings.dataDirectory) return NO;
    if (self.dataDirectory && ![self.dataDirectory isEqualToString:settings.dataDirectory]) return NO;
    if (!self.logFile && settings.logFile) return NO;
    if (self.logFile && ![self.logFile isEqualToString:settings.logFile]) return NO;
    if (self.startup != settings.startup) return NO;
    return YES;
}
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (!object) return NO;
    if (![object isKindOfClass:[PGServerSettings class]]) return NO;
    return [self isEqualToSettings:(PGServerSettings *)object];
}
- (void)setUsername:(NSString *)username
{
    _username = TrimToNil(username);
}
- (void)setBinDirectory:(NSString *)binDirectory
{
    _binDirectory = TrimToNil(binDirectory);
}
- (void)setDataDirectory:(NSString *)dataDirectory
{
    _dataDirectory = TrimToNil(dataDirectory);
}
- (void)setLogFile:(NSString *)logFile
{
    _logFile = TrimToNil(logFile);
}
- (NSDictionary *)properties
{
    return @{
             PGServerUsernameKey:self.username?:@"",
             PGServerBinDirectoryKey:self.binDirectory?:@"",
             PGServerDataDirectoryKey:self.dataDirectory?:@"",
             PGServerLogFileKey:self.logFile?:@"",
             PGServerPortKey:self.port?:@"",
             PGServerStartupKey:ServerStartupDescription(self.startup)
    };
}
- (void)setProperties:(NSDictionary *)properties
{
    if (properties == nil) return;
    self.username = ToString(properties[PGServerUsernameKey]);
    self.binDirectory = ToString(properties[PGServerBinDirectoryKey]);
    self.dataDirectory = ToString(properties[PGServerDataDirectoryKey]);
    self.logFile = ToString(properties[PGServerLogFileKey]);
    self.port = ToString(properties[PGServerPortKey]);
    self.startup = ToServerStartup(properties[PGServerStartupKey]);
}
- (BOOL)hasDifferentUser
{
    NSString *currentUser = NSUserName();
    return NonBlank(self.username) && ![[currentUser lowercaseString] isEqualToString:[self.username lowercaseString]];
}
- (BOOL)valid
{
    return !(self.invalidUsername || self.invalidBinDirectory || self.invalidDataDirectory || self.invalidLogFile || self.invalidPort);
}
- (void)setValid
{
    self.invalidUsername = self.invalidBinDirectory = self.invalidDataDirectory = self.invalidLogFile = self.invalidPort = NO;
}
+ (BOOL)containsServerSettings:(NSDictionary *)properties
{
    if (!properties[PGServerUsernameKey]) return NO;
    if (!properties[PGServerBinDirectoryKey]) return NO;
    if (!properties[PGServerDataDirectoryKey]) return NO;
    if (!properties[PGServerLogFileKey]) return NO;
    if (!properties[PGServerPortKey]) return NO;
    if (!properties[PGServerStartupKey]) return NO;
    return YES;
}
- (NSString *)description
{
    return self.properties.description;
}

@end



#pragma mark - PGServer

@implementation PGServer

@synthesize fullName = _fullName;

#pragma mark Lifecycle

- (id)init
{
    return [self initWithName:nil domain:nil settings:nil];
}

- (id)initWithName:(NSString *)name domain:(NSString *)domain
{
    return [self initWithName:name domain:domain settings:nil];
}

- (id)initWithName:(NSString *)name domain:(NSString *)domain settings:(PGServerSettings *)settings
{
    self = [super init];
    if (self) {
        self.name = name;
        self.domain = domain;
        self.settings = settings;
        self.dirtySettings = nil;
        self.status = PGServerStatusUnknown;
        self.error = nil;
    }
    return self;
}

- (void)setName:(NSString *)name
{
    _name = TrimToNil(name) ?: @"";
    _fullName = nil;
}

- (void)setDomain:(NSString *)domain
{
    _domain = TrimToNil(domain) ?: @"";
    _fullName = nil;
}

- (NSString *)fullName
{
    if (_fullName) return _fullName;
    return _fullName = !(_domain&&_name) ? @"" : [NSString stringWithFormat:@"%@.%@", _domain?:@"", _name?:@""];
}

- (void)setSettings:(PGServerSettings *)settings
{
    _settings = settings ?: [[PGServerSettings alloc] init];
}

- (BOOL)canStartAtLogin
{
    return !self.settings.hasDifferentUser;
}

- (BOOL)needsAuthorization
{
    if (self.settings.hasDifferentUser) return YES;
    if (self.settings.startup == PGServerStartupAtBoot) return YES;
    return NO;
}

- (BOOL)logExists
{
    if (!NonBlank(self.log)) return NO;
    
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:self.log isDirectory:&isDirectory] && !isDirectory;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@\n"
                                "Log:    %@\n"
                                "Exists: %@\n"
                                "Root:   %@",
            self.name, self.settings.description, [self.log stringByAbbreviatingWithTildeInPath], self.logExists?@"YES":@"NO", self.needsAuthorization?@"YES":@"NO"];
}

@end

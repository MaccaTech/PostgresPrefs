//
//  PGSearchController.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 16/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGSearchController.h"

#pragma mark - Interfaces

@interface PGSearchController()

/// Internal list of servers found, updated as results come in
@property (nonatomic, strong) NSMutableArray *mutableServers;
/// Last time search was run. Used to prevent search being run too frequently.
@property (nonatomic, strong) NSDate *lastUpdated;

@property (nonatomic, strong) NSMetadataQuery *enterpriseDBQuery;
@property (nonatomic, strong) NSMetadataQuery *postgresappQuery;
@property (nonatomic, strong) NSMetadataQuery *spotlightQuery;

/**
 * Search for "pg_env.sh" and run it
 */
- (void)findServersFromEnterpriseDB;
/**
 * Search for "/Applications/.../Postgres.app"
 */
- (void)findServersFromPostgresapp;
/**
 * Search for .plist files anywhere with "postgre" in name
 */
- (void)findServersFromSpotlight;

/**
 * Registers this class with NSNotificationCenter to receive query updates
 */
- (void)didAddMetadataQuery:(NSMetadataQuery *)query;
/**
 * Unrregisters this class from NSNotificationCenter for the query
 */
- (void)willRemoveMetadataQuery:(NSMetadataQuery *)query;
/**
 * Callback for NSNotificationCenter query event
 */
- (void)queryDidUpdate:(NSNotification *)notification;
/**
 * Callback for NSNotificationCenter query event
 */
- (void)initialGatherComplete:(NSNotification *)notification;


/**
 * Utility method - scan all nested dirs for files matching predicate
 */
- (NSArray *)findFilesInDir:(NSString *)dir predicate:(NSPredicate *)predicate;
/**
 * Utility method - check if directory exists
 */
- (BOOL)dirExists:(NSString *)dir;

@end



#pragma mark - PGSearch

@implementation PGSearchController

#pragma mark Lifecycle
- (id)init
{
    return [self initWithDelegate:nil];
}
- (id)initWithDelegate:(id<PGSearchDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.mutableServers = [NSMutableArray array];
        self.delegate = delegate;
    }
    return self;
}



#pragma mark Properties

- (NSArray *)servers
{
    return _mutableServers;
}
- (void)setEnterpriseDBQuery:(NSMetadataQuery *)enterpriseDBQuery
{
    if (enterpriseDBQuery == _enterpriseDBQuery) return;
    
    [self willRemoveMetadataQuery:_enterpriseDBQuery];
    _enterpriseDBQuery = enterpriseDBQuery;
    [self didAddMetadataQuery:enterpriseDBQuery];
}
- (void)setPostgresappQuery:(NSMetadataQuery *)postgresappQuery
{
    if (postgresappQuery == _postgresappQuery) return;
    
    [self willRemoveMetadataQuery:_postgresappQuery];
    _postgresappQuery = postgresappQuery;
    [self didAddMetadataQuery:postgresappQuery];
}
- (void)setSpotlightQuery:(NSMetadataQuery *)spotlightQuery
{
    if (spotlightQuery == _spotlightQuery) return;
    
    [self willRemoveMetadataQuery:_spotlightQuery];
    _spotlightQuery = spotlightQuery;
    [self didAddMetadataQuery:spotlightQuery];
}
- (void)didAddMetadataQuery:(NSMetadataQuery *)query
{
    if (!query) return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryDidUpdate:) name:NSMetadataQueryDidUpdateNotification object:query];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialGatherComplete:) name:NSMetadataQueryDidFinishGatheringNotification object:query];
}
- (void)willRemoveMetadataQuery:(NSMetadataQuery *)query
{
    if (!query) return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidUpdateNotification object:query];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidFinishGatheringNotification object:query];
}



#pragma mark Main Methods

- (void)startFindServers
{
    // Only re-scan if 1 minute has elapsed since last scan
    if (self.lastUpdated && [self.lastUpdated timeIntervalSinceNow] > -60) return;
    self.lastUpdated = [NSDate date];
    
    [self.mutableServers removeAllObjects];

    DLog(@"Find servers...");
    [self findServersFromSpotlight];
    [self findServersFromPostgresapp];
    [self findServersFromEnterpriseDB];
}



#pragma mark Servers

- (void)findServersFromEnterpriseDB
{
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    query.predicate = [NSPredicate predicateWithFormat:@"kMDItemFSName == %@", @"pg_env.sh"];
    query.searchScopes = @[NSMetadataQueryLocalComputerScope];
    
    self.enterpriseDBQuery = query;
    [query startQuery];
}

- (void)findServersFromPostgresapp
{
    // Postgres.app not installed
    if (![self dirExists:@"/Applications/Postgres.app"]) return;
    
    // Postgres.app installed, do a spotlight search for data dirs
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    query.predicate = [NSPredicate predicateWithFormat:@"kMDItemFSName ==[c] %@", @"postgresql.conf"];
    query.searchScopes = @[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]];
    
    self.postgresappQuery = query;
    [query startQuery];
}

- (void)findServersFromSpotlight
{
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    query.predicate = [NSPredicate predicateWithFormat:@"kMDItemFSName like[c] %@", @"*postgre*.plist"];
    query.searchScopes = @[NSMetadataQueryLocalComputerScope];
    
    self.spotlightQuery = query;
    [query startQuery];
}

- (PGServer *)serverFromLaunchAgent:(NSString *)agentFile
{
    NSString *PGNAME = nil;
    NSString *PGDOMAIN = nil;
    NSString *PGUSER = nil;
    NSString *PGBIN  = nil;
    NSString *PGDATA = nil;
    NSString *PGLOG  = nil;
    NSString *PGPORT = nil;
    PGServerStartup PGSTART = PGServerStartupManual;
    NSString *filepath = nil;
    NSString *executable = nil;
    NSUInteger index = 0;
    
    NSDictionary *data = [[NSDictionary alloc] initWithContentsOfFile:agentFile];
    DLog(@"Launch Agent: %@", data);
    
    NSString *name = TrimToNil(ToString(data[@"Label"]));
    NSString *username = TrimToNil(ToString(data[@"UserName"]));
    NSArray *programArgs = ToArray(data[@"ProgramArguments"]);
    BOOL runAtLoad = ToBOOL(data[@"RunAtLoad"]);
    NSDictionary *environmentVars = ToDictionary(data[@"EnvironmentVariables"]);
    NSString *stdout = TrimToNil(ToString(data[@"StandardOutPath"]));
    NSString *stderr = TrimToNil(ToString(data[@"StandardErrorPath"]));
    NSString *workingDir = TrimToNil(ToString(data[@"WorkingDirectory"]));
    
    // PGNAME
    if (!name) return nil;
    name = [name stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    // Name may end in a version number, e.g. com.blah.postgressql-9.4
    // So the final dot may not be a real "package-separator"
    // Hence the need for an ugly regex...
    PGNAME = [name stringByReplacingOccurrencesOfString:@"\\A.*\\.(.*?[\\p{Ll}\\p{Lu}\\p{Lt}\\p{Lo}].*?)\\z" withString:@"$1" options:NSRegularExpressionSearch range:NSMakeRange(0, name.length)];
    PGDOMAIN = [name substringToIndex:name.length-(PGNAME.length+1)];
    
    // PGUSER
    PGUSER = username;
    
    // PGBIN
    if (programArgs.count == 0) return nil;
    filepath = ToString(programArgs[0]);
    executable = [filepath lastPathComponent];
    
    // Abort if not a Postgres agent, unless created by this tool
    if (! (
           [executable isEqualToString:@"postgres"] ||
           [executable isEqualToString:@"pg_ctl"] ||
           [executable isEqualToString:@"postmaster"] ||
           [PGNAME hasPrefix:PGPrefsAppID])
        ) return nil;
    PGBIN = [filepath stringByDeletingLastPathComponent];
    
    // PGDATA
    index = [programArgs indexOfObject:@"-D"];
    if (index != NSNotFound && index+1 < programArgs.count) {
        PGDATA = ToString(programArgs[index+1]);
    }
    if (!NonBlank(PGDATA)) {
        for (NSString *programArg in programArgs) {
            NSString *arg = TrimToNil(programArg);
            if ([arg hasPrefix:@"-D"]) PGDATA = [arg substringFromIndex:2];
        }
    }
    if (!NonBlank(PGDATA)) {
        PGDATA = ToString(environmentVars[@"PGDATA"]);
    }
    if (!NonBlank(PGDATA)) {
        PGDATA = workingDir;
    }
    
    // PGLOG
    index = [programArgs indexOfObject:@"-r"];
    if (index != NSNotFound && index+1 < programArgs.count) {
        PGLOG = ToString(programArgs[index+1]);
    }
    // Only use STDOUT/STDERR if agent was not created by this tool
    if (!NonBlank(PGLOG) && ![name hasPrefix:PGPrefsAppID]) {
        PGLOG = ToString(stderr);
        if (!NonBlank(PGLOG)) PGLOG = ToString(stdout);
    }

    // PGPORT
    index = [programArgs indexOfObject:@"-p"];
    if (index != NSNotFound && index+1 < programArgs.count) {
        PGPORT = ToString(programArgs[index+1]);
    }
    if (!NonBlank(PGPORT)) {
        PGPORT = ToString(environmentVars[@"PGPORT"]);
    }
    
    // PGSTART
    if (runAtLoad) {
        PGSTART = [agentFile hasPrefix:@"/LibraryLaunchDaemons"] ? PGServerStartupAtBoot : PGServerStartupAtLogin;
    }
    
    // Create servers
    PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:PGUSER binDirectory:PGBIN dataDirectory:PGDATA logFile:PGLOG port:PGPORT startup:PGSTART];
    PGServer *server = [[PGServer alloc] initWithName:PGNAME domain:PGDOMAIN settings:settings];
    [self simplifyServerSettings:server];
    return server;
}
- (NSArray *)serversFromEnterpriseDBFiles:(NSArray *)files
{
    DLog(@"EnterpriseDB files: %@", @(files.count));
    if (files.count == 0) return nil;
    
    // Prepare shell command to run pg_env.sh and print environment variables
    static NSString *command;
    if (!command) command = [NSString stringWithFormat:@""
                             "source \"%%@\" 2>/dev/null && "
                             "PGBIN=$(dirname `which postgres 2>/dev/null` 2>/dev/null) && "
                             "echo \""
                             "{\n"
                             "    \\\"%@\\\": \\\"${PGBIN}\\\",\n"
                             "    \\\"%@\\\": \\\"${PGDATA}\\\",\n"
                             "    \\\"%@\\\": \\\"${PGUSER}\\\",\n"
                             "    \\\"%@\\\": \\\"${PGPORT}\\\"\n"
                             "}\"", PGServerBinDirectoryKey, PGServerDataDirectoryKey, PGServerUsernameKey, PGServerPortKey];
    
    // Create servers
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        
        // Execute pg_env.sh in shell and print environment variables.
        NSString *json = [PGProcess runShellCommand:[NSString stringWithFormat:command, file] withArgs:nil];
        DLog(@"RESULT: %@", json);
        if (!NonBlank(json)) continue;
        
        // Parse json
        NSError *error;
        NSDictionary *properties = JsonToDictionary(json, error);
        if (error) {
            DLog(@"%@\n\n%@", json, error);
            continue;
        }
        if (properties.count == 0) continue;
        
        // Create server
        PGServerSettings *settings = [[PGServerSettings alloc] initWithProperties:properties];
        PGServer *server = [[PGServer alloc] initWithName:@"postgresql" domain:@"com.enterprisedb" settings:settings];
        [self simplifyServerSettings:server];
        [result addObject:server];
    }
    
    return result.count == 0 ? nil : result;
}
- (NSArray *)serversFromPostgresappFiles:(NSArray *)files
{
    DLog(@"Postgresapp files: %@", @(files.count));
    if (files.count == 0) return nil;
    
    // Find the bin dir under /Applications/Postgres.app, otherwise give up
    NSArray *filesCalledPostgres = [self findFilesInDir:@"/Applications/Postgres.app" predicate:[NSPredicate predicateWithFormat:@"SELF endswith %@", @"/postgres"]];
    DLog(@"Postgres files: %@", filesCalledPostgres);
    NSString *binDir = nil;
    for (NSString *fileCalledPostgres in filesCalledPostgres) {
        NSString *dirname = [fileCalledPostgres stringByDeletingLastPathComponent];
        if ([[dirname lastPathComponent] isEqualToString:@"bin"]) {
            binDir = dirname;
            break;
        }
    }
    if (!binDir) return nil;
    
    // Create the servers
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        NSString *dataDir = [file stringByDeletingLastPathComponent];
        PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:nil binDirectory:binDir dataDirectory:dataDir logFile:nil port:nil startup:PGServerStartupManual];
        PGServer *server = [[PGServer alloc] initWithName:[dataDir lastPathComponent] domain:@"postgresapp.com" settings:settings];
        [self simplifyServerSettings:server];
        [result addObject:server];
    }
    
    return result;
}
- (NSArray *)serversFromSpotlightFiles:(NSArray *)files
{
    DLog(@"Spotlight files: %@", @(files.count));
    if (files.count == 0) return nil;
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        PGServer *server = [self serverFromLaunchAgent:file];
        if (!server) continue;
        
        [self simplifyServerSettings:server];
        [result addObject:server];
    }
    return result;
}

- (void)simplifyServerSettings:(PGServer *)server
{
    PGServerSettings *settings = server.settings;
    if ([settings.username isEqualToString:NSUserName()]) settings.username = nil;
    settings.binDirectory = [settings.binDirectory stringByAbbreviatingWithTildeInPath];
    settings.dataDirectory = [settings.dataDirectory stringByAbbreviatingWithTildeInPath];
    settings.logFile = [settings.logFile stringByAbbreviatingWithTildeInPath];
}



#pragma mark NSMetadataQuery

- (void)queryDidUpdate:(NSNotification *)notification
{
    DLog(@"A data batch has been received");
}
- (void)initialGatherComplete:(NSNotification *)notification
{
    NSMetadataQuery *query = notification.object;
    [query stopQuery];
    
    // Get the file paths found
    NSMutableArray *files = query.resultCount == 0 ? nil : [NSMutableArray arrayWithCapacity:query.resultCount];
    for (NSMetadataItem *item in query.results)
        [files addObject:[item valueForAttribute:(NSString *) kMDItemPath]];
    
    // Process results
    NSArray *servers = nil;
    if (query == self.enterpriseDBQuery) {
        self.enterpriseDBQuery = nil;
        servers = [self serversFromEnterpriseDBFiles:files];
    } else if (query == self.postgresappQuery) {
        self.postgresappQuery = nil;
        servers = [self serversFromPostgresappFiles:files];
    } else if (query == self.spotlightQuery) {
         self.spotlightQuery = nil;
        servers = [self serversFromSpotlightFiles:files];
    } else {
        DLog(@"ERROR: Unknown query: %@", query);
    }
    
    // No servers found
    if (servers.count == 0) return;
    
    // Servers found - notify delegate
    MainThread(^{
        [self.mutableServers addObjectsFromArray:servers];
        [self.delegate didFindMoreServers:self];
    });
}



#pragma mark Utils

- (NSArray *)findFilesInDir:(NSString *)dir predicate:(NSPredicate *)predicate
{
    if (![self dirExists:dir]) return nil;
    
    // Search
    NSMutableArray *result = [NSMutableArray array];
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dir];
    NSString *file;
    while ((file = [dirEnum nextObject])) {
        if ([predicate evaluateWithObject:file]) [result addObject:[dir stringByAppendingPathComponent:file]];
    }
    return result.count > 0 ? result : nil;
}

- (BOOL)dirExists:(NSString *)dir
{
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDirectory] && isDirectory;
}

@end

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

@end



#pragma mark - PGSearch

@implementation PGSearchController

#pragma mark Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        self.mutableServers = [NSMutableArray array];
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

- (void)findInstalledServers
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

- (void)findLoadedServers:(void(^)(NSArray *servers))found authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    BackgroundThread(^{
        
        NSMutableArray *servers = [NSMutableArray array];
        [self addLoadedServersForRootUser:YES authorization:authorization authStatus:authStatus toServers:servers];
        [self addLoadedServersForRootUser:NO authorization:authorization authStatus:authStatus toServers:servers];
        
        if (found) found(servers);
    });
}



#pragma mark Servers

- (void)addLoadedServersForRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus toServers:(NSMutableArray *)servers
{
    NSString *error = nil;
    NSArray *daemons = [PGLaunchd loadedDaemonsWithNameLike:@"*postgre*" forRootUser:root authorization:authorization authStatus:authStatus error:&error];
    if (daemons.count == 0) return;
    
    for (NSDictionary *daemon in daemons) {
        PGServer *server = [self.serverController serverFromDaemon:daemon forRootUser:root];
        if (server) [servers addObject:server];
    }
}

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
    if (!DirExists(@"/Applications/Postgres.app")) return;
    
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
                             "}\"",
                             PGServerBinDirectoryKey,
                             PGServerDataDirectoryKey,
                             PGServerUsernameKey,
                             PGServerPortKey];
    
    // Create servers
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        
        // Execute pg_env.sh in shell and print environment variables.
        NSString *json = [PGProcess runShellCommand:[NSString stringWithFormat:command, file] error:nil];
        DLog(@"RESULT: %@", json);
        if (!NonBlank(json)) continue;
        
        // Parse json
        NSString *error;
        NSDictionary *properties = JsonToDictionary(json, &error);
        if (error) {
            DLog(@"%@\n\n%@", json, error);
            continue;
        }
        if (properties.count == 0) continue;
        
        // Create server
        PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:properties[PGServerUsernameKey] binDirectory:properties[PGServerBinDirectoryKey] dataDirectory:properties[PGServerDataDirectoryKey] logFile:nil port:properties[PGServerPortKey] startup:PGServerStartupManual];
        PGServer *server = [self.serverController serverFromSettings:settings name:@"postgresql" domain:@"com.enterprisedb"];
        
        if (server) [result addObject:server];
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
        NSString *name = [dataDir lastPathComponent];
        PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:nil binDirectory:binDir dataDirectory:dataDir logFile:nil port:nil startup:PGServerStartupManual];
        PGServer *server = [self.serverController serverFromSettings:settings name:name domain:@"postgresapp.com"];
        
        if (server) [result addObject:server];
    }
    
    return result;
}
- (NSArray *)serversFromSpotlightFiles:(NSArray *)files
{
    DLog(@"Spotlight files: %@", @(files.count));
    if (files.count == 0) return nil;
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:files.count];
    for (NSString *file in files) {
        PGServer *server = [self.serverController serverFromDaemonFile:file];
        
        if (server) [result addObject:server];
    }
    return result;
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
    if (!DirExists(dir)) return nil;
    
    // Search
    NSMutableArray *result = [NSMutableArray array];
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dir];
    NSString *file;
    while ((file = [dirEnum nextObject])) {
        if ([predicate evaluateWithObject:file]) [result addObject:[dir stringByAppendingPathComponent:file]];
    }
    return result.count > 0 ? result : nil;
}

@end

//
//  PGSearchController.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 16/7/15.
//  Copyright (c) 2011-2020 Macca Tech Ltd. (http://macca.tech)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "PGSearchController.h"

#pragma mark - Interfaces

@interface PGSearchController ()

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

- (NSArray *)startedServers
{
    NSArray *loadedServers = [self loadedServers];
    NSArray *runningServers = [self runningServers];
    
    if (loadedServers.count == 0) return runningServers;
    if (runningServers.count == 0) return loadedServers;

    // Combine servers lists
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:loadedServers.count + runningServers.count];
    [result addObjectsFromArray:loadedServers];
    
    // Only add running servers that weren't started by launchd
    NSMutableDictionary *pids = [NSMutableDictionary dictionaryWithCapacity:loadedServers.count];
    for (PGServer *server in loadedServers) {
        if (server.pid > 0) pids[@(server.pid)] = server;
    }
    for (PGServer *server in runningServers) {
        if (server.pid <= 0) continue;
        
        PGServer *loadedServer = pids[@(server.pid)];
        if (loadedServer) {
            // Add missing properties to loaded server from runing server.
            if (server.settings.username &&
                !loadedServer.settings.username) {
                loadedServer.settings.username = server.settings.username;
            }
        } else {
            [result addObject:server];
        }
    }
    
    return [NSArray arrayWithArray:result];
}



#pragma mark Servers

- (NSArray *)runningServers
{
    NSArray *processes = [PGProcess runningProcessesWithNameLike:@".*postgre.*"];
    if (processes.count == 0) return nil;
    
    NSMutableArray *servers = [NSMutableArray arrayWithCapacity:processes.count];
    NSUInteger numberOfServers = 0;
    
    for (PGProcess *process in processes) {
        PGServer *server = [self.serverController serverFromProcess:process];
        [servers addObject:(server ?: [NSNull null])];
        if (server) { numberOfServers++; }
    }
    
#ifdef DEBUG
    DLog(@"Postgres Processes:\n%@\n\nOther Processes:\n%@",
         [processes objectsAtIndexes:[servers indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) { return obj != [NSNull null]; }]],
         [processes objectsAtIndexes:[servers indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) { return obj == [NSNull null]; }]]
    );
#endif
    
    return numberOfServers == 0 ? nil : [servers filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) { return obj != [NSNull null]; }]];
}
- (NSArray *)loadedServers
{
    NSMutableArray *result = [NSMutableArray array];
    [self addLoadedServersForRootUser:YES toServers:result];
    [self addLoadedServersForRootUser:NO toServers:result];
    return result.count == 0 ? nil : [NSArray arrayWithArray:result];
}
- (void)addLoadedServersForRootUser:(BOOL)root toServers:(NSMutableArray *)servers
{
    NSArray *daemons = [PGLaunchd loadedDaemonsWithNameLike:@"*postgre*" forRootUser:root];
    if (daemons.count == 0) return;
    
    for (NSDictionary *daemon in daemons) {
        PGServer *server = [self.serverController serverFromLoadedDaemon:daemon forRootUser:root];
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
    if (![PGFile dirExists:@"/Applications/Postgres.app"]) return;
    
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
    query.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"kMDItemFSName like[c] %@", @"*postgre*"], [NSPredicate predicateWithFormat:@"kMDItemFSName like[c] %@", @"*.plist"]]];
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
        
        // Security: do not execute pg_env.sh unless it and all its parent folders
        // are owned by root.
        NSString *pgenvPath = [[file stringByResolvingSymlinksInPath] stringByExpandingTildeInPath];
        if (![self pathIsOwnedByRoot:pgenvPath]) { continue; }
        
        // Security: do not execute pg_env.sh unless it looks like it is part
        // of a standard EDB installation
        NSString *pgenvDir = [pgenvPath stringByDeletingLastPathComponent];
        if (![self pathIsPostgreSQLInstallDir:pgenvDir]) { continue; }
        
        // Execute pg_env.sh in shell and print environment variables.
        NSString *json = [PGProcess runShellCommand:[NSString stringWithFormat:command, pgenvPath] error:nil];
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
        NSString *name = [self nameFromPostgreSQLInstallDir:pgenvDir];
        NSString *domain = @"com.enterprisedb";
        PGServerSettings *settings = [[PGServerSettings alloc] initWithUsername:properties[PGServerUsernameKey] binDirectory:properties[PGServerBinDirectoryKey] dataDirectory:properties[PGServerDataDirectoryKey] logFile:nil port:properties[PGServerPortKey] startup:PGServerStartupManual];
        PGServer *server = [self.serverController serverFromSettings:settings name:name domain:domain];
        
        if (server) { [self addServerUnlessDuplicate:server toServers:result]; }
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
        
        if (server) { [self addServerUnlessDuplicate:server toServers:result]; }
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
        
        if (server) { [self addServerUnlessDuplicate:server toServers:result]; }
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
    NSMutableArray *files = nil;
    if (query.resultCount > 0) {
        files = [NSMutableArray arrayWithCapacity:query.resultCount];
        for (NSMetadataItem *item in query.results) {
            // Bugfix in version 2.4.1 - handle fact that this may return nil
            NSString *path = [item valueForAttribute:(NSString *) kMDItemPath];
            if (!path) continue;
            
            [files addObject:path];
        }
        if (files.count == 0) files = nil;
    }
    
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
        for (PGServer *server in servers) {
            if (server) { [self addServerUnlessDuplicate:server toServers:self.mutableServers]; }
        }
        [self.delegate didFindMoreServers:self];
    });
}



#pragma mark Utils

- (NSArray *)findFilesInDir:(NSString *)dir predicate:(NSPredicate *)predicate
{
    if (![PGFile dirExists:dir]) return nil;
    
    // Search
    NSMutableArray *result = [NSMutableArray array];
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dir];
    NSString *file;
    while ((file = [dirEnum nextObject])) {
        if ([predicate evaluateWithObject:file]) [result addObject:[dir stringByAppendingPathComponent:file]];
    }
    return result.count > 0 ? result : nil;
}

- (BOOL)addServerUnlessDuplicate:(PGServer *)newServer toServers:(NSMutableArray *)servers
{
    for (PGServer *server in servers) {
        if ([server.name isEqualToString:newServer.name] &&
            [server.settings isEqualToSettings:newServer.settings]) { return NO;
        }
    }
    
    [servers addObject:newServer];
    return YES;
}

- (BOOL)pathIsOwnedByRoot:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    do {
        // Ensure path owned by root
        NSError *error;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (error) { return NO; }
        if (!attributes) { return NO; }
        if (![[attributes fileOwnerAccountID] isEqualToNumber:@(0)]) { return NO; }
        
        // Set to parent dir
        NSString *parentDir = [path stringByDeletingLastPathComponent];
        if (path.length == parentDir.length) { break; }
        path = parentDir;
    } while (true);
    return YES;
}

- (BOOL)pathIsPostgreSQLInstallDir:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir1, isDir2, isDir3, exists1, exists2, exists3;
    exists1 = [fileManager fileExistsAtPath:[[path stringByAppendingPathComponent:@"include"] stringByAppendingPathComponent:@"postgresql"] isDirectory:&isDir1];
    exists2 = [fileManager fileExistsAtPath:[[path stringByAppendingPathComponent:@"lib"] stringByAppendingPathComponent:@"postgresql"] isDirectory:&isDir2];
    exists3 = [fileManager fileExistsAtPath:[[path stringByAppendingPathComponent:@"share"] stringByAppendingPathComponent:@"postgresql"] isDirectory:&isDir3];
    if (!(exists1 && exists2 && exists3)) { return NO; }
    if (!(isDir1 && isDir2 && isDir3)) { return NO; }
    return YES;
}

- (NSString *)nameFromPostgreSQLInstallDir:(NSString *)path
{
    // Try to deduce a sensible name from install dir, e.g.:
    //   /Library/PostgreSQL/12 -> "PostgreSQL 12"
    //   /Library/MyDifferentName -> "MyDifferentName"
    NSString *dirname = [path lastPathComponent];
    if ([[dirname lowercaseString] containsString:@"ostgre"]) {
        return dirname;
    } else {
        NSString *parentDirname = [[path stringByDeletingLastPathComponent] lastPathComponent];
        if ([[parentDirname lowercaseString] containsString:@"ostgre"]) {
            return [NSString stringWithFormat:@"%@ %@", parentDirname, dirname];
        } else {
            return dirname;
        }
    }
}

@end

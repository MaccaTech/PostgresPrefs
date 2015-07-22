//
//  PGServers.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 11/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGServerDataStore.h"

#pragma mark - Interfaces

@interface PGServerDataStore()

@property (nonatomic, strong) PGData *data;
@property (nonatomic, strong) NSMutableDictionary *serversCache;
@property (nonatomic, strong) NSMutableArray *serversOrderedByName;

/**
 * Gets the next available unique server name for the specified prefix.
 */
- (NSString *)unusedServerNameWithPrefix:(NSString *)prefix;

/**
 * Clears cached data whens servers change
 */
- (void)didChangeServers;

@end



#pragma mark - PGServers

@implementation PGServerDataStore

- (id)init
{
    self = [super init];
    if (self) {
        self.serversCache = [NSMutableDictionary dictionary];
        self.data = [[PGData alloc] initWithAppID:[NSString stringWithFormat:@"%@.%@", PGPrefsAppID, @"servers"]];
    }
    return self;
}

- (NSArray *)servers
{
    if (self.serversOrderedByName != nil) return self.serversOrderedByName;
    
    // Generate ordered servers list
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:MAX(1,self.serversCache.count)];
    NSArray *orderedNames = [self.serversCache.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *name in orderedNames) [result addObject:self.serversCache[name]];
    
    DLog(@"Servers: %@", orderedNames);
    
    return self.serversOrderedByName = result;
}

- (void)loadServers
{
    [self.serversCache removeAllObjects];
    [self didChangeServers];
    
    NSDictionary *servers = [self.data allData];
    if (servers.count == 0) return;
    
    for (NSString *name in servers.allKeys) {
        NSDictionary *serverProperties = servers[name];
        
        if (![PGServerSettings containsServerSettings:serverProperties]) continue;
        
        self.serversCache[name] = [[PGServer alloc] initWithName:name domain:PGPrefsAppID settings:[[PGServerSettings alloc] initWithProperties:serverProperties]];
    }

}

- (void)synchronize
{
    [self.data synchronize];
}

- (PGServer *)serverWithName:(NSString *)name
{
    return self.serversCache[name];
}

- (PGServer *)addServer
{
    NSString *name = [self unusedServerNameWithPrefix:PGServerDefaultName];
    PGServer *result = [[PGServer alloc] initWithName:name domain:PGPrefsAppID];
    
    [self.data setData:result.settings.properties forKey:name];
    [self.data synchronize];
    self.serversCache[name] = result;

    [self didChangeServers];
    
    return result;
}

- (BOOL)saveServer:(PGServer *)server
{
    if (!server) return NO;
    if (!NonBlank(server.name)) return NO;
    
    if (!server.dirtySettings) return YES;
    
    [self.data setData:server.dirtySettings.properties forKey:server.name];
    [self.data synchronize];
    server.settings = server.dirtySettings;
    server.dirtySettings = nil;
    
    [self didChangeServers];
    
    return YES;
}

- (BOOL)setName:(NSString *)name forServer:(PGServer *)server
{
    if (!server) return NO;
    if (!NonBlank(name)) return NO;
    
    PGServer *existing = self.serversCache[name];
    if (existing) return NO;
    
    // Remove old name
    if (NonBlank(server.name)) {
        [self.data removeKey:server.name];
        [self.serversCache removeObjectForKey:server.name];
    }
    
    // Set new name
    [self.data setData:server.settings.properties forKey:name];
    [self.data synchronize];
    self.serversCache[name] = server;
    server.name = name;
    
    [self didChangeServers];
    
    return YES;
}

- (void)removeServer:(PGServer *)server
{
    if (!server) return;
    if (!NonBlank(server.name)) return;
    
    [self.data removeKey:server.name];
    [self.data synchronize];
    [self.serversCache removeObjectForKey:server.name];
    
    [self didChangeServers];
}

- (void)removeAllServers
{
    NSArray *names = self.serversCache.allKeys;
    if (names.count == 0) return;
    
    [self.data removeKeys:names];
    [self.data synchronize];
    [self.serversCache removeObjectsForKeys:names];

    [self didChangeServers];
}



#pragma mark Private

- (void)didChangeServers
{
    self.serversOrderedByName = nil;
}

- (NSString *)unusedServerNameWithPrefix:(NSString *)prefix
{
    // First, if no other servers exist with this prefix, then use it as-is
    if (!self.serversCache[prefix]) return prefix;
    
    // Get the existing names with prefix
    NSMutableDictionary *existingNames = [NSMutableDictionary dictionaryWithCapacity:self.servers.count];
    for (PGServer *server in self.servers) {
        if ([server.name hasPrefix:prefix]) existingNames[server.name] = [NSNull null];
    }
    
    // Now cycle up from 1 until we find a free name
    for (NSInteger i = 1; i < 10000; i++) {
        NSString *name = [NSString stringWithFormat:@"%@ (%ld)", prefix, (long) i];
        if (!existingNames[name]) return name;
    }
    
    // Give up - use an error name
    return @"*** ERRROR ***";
}

@end

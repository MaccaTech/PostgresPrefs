//
//  PGServerDataStore.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 11/7/15.
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

#import "PGServerDataStore.h"

#pragma mark - Interfaces

@interface PGServerDataStore ()

/// Used to peform the load/save using CFPreferences
@property (nonatomic, strong) PGData *data;

/// Used to keep track of last-saved name for server
@property (nonatomic, strong) NSMutableDictionary *namesCache;

/// Used to cache servers by name
@property (nonatomic, strong) NSMutableDictionary *serversCache;

/// Used to return ordered servers list externally
@property (nonatomic, strong) NSMutableArray *serversOrderedByName;

/**
 * Gets the next available unique server name for the specified prefix.
 */
- (NSString *)unusedServerNameWithPrefix:(NSString *)prefix;

@end



#pragma mark - PGServers

@implementation PGServerDataStore

- (id)init
{
    self = [super init];
    if (self) {
        self.namesCache = [NSMutableDictionary dictionary];
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
    [self clearCache];
    
    NSDictionary *servers = [self.data allData];
    if (servers.count == 0) return;
    
    for (NSString *name in servers.allKeys) {
        
        // Create the server
        PGServer *server = [self.serverController serverFromProperties:servers[name] name:name];
        if (!server) continue;
        
        // Cache
        [self addToCache:server];
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
    return [self addServerWithName:PGServerDefaultName];
}

- (PGServer *)addServerWithName:(NSString *)prefix
{
    return [self addServerWithName:prefix settings:nil];
}

- (PGServer *)addServerWithName:(NSString *)prefix settings:(PGServerSettings *)settings
{
    if (!NonBlank(prefix)) prefix = PGServerDefaultName;
    NSString *name = [self unusedServerNameWithPrefix:prefix];
    PGServer *server = [self.serverController serverFromSettings:settings name:name domain:PGPrefsAppID];
    if (!server) return nil;
    
    [self addToCache:server];
    
    [self.data setData:server.properties forKey:name];
    [self.data synchronize];
    
    return server;
}

- (BOOL)saveServer:(PGServer *)server
{
    if (!server) return NO;
    if (!NonBlank(server.name)) return NO;
 
    PGServer *serverForNameInCache = self.serversCache[server.name];
    
    // Name change
    if (serverForNameInCache != server) {
        
        // Clash with existing server
        if (serverForNameInCache) return NO;
        
        // Remove old name
        if (server.saveable) {
            NSString *oldName = self.namesCache[server.uid];
            if (NonBlank(oldName)) {
                [self.data removeKey:oldName];
                [self.data synchronize];
            }
        }
        [self removeFromCache:server];
        
        // Cache new name
        [self addToCache:server];
    }
    
    DLog(@"%@", server);
    if (server.saveable) {
        [self.data setData:server.properties forKey:server.name];
        [self.data synchronize];
    }
    
    return YES;
}

- (void)removeServer:(PGServer *)server
{
    if (!server) return;
    if (!NonBlank(server.name)) return;
    
    if (server.saveable) {
        [self.data removeKey:server.name];
        [self.data synchronize];
    }

    [self removeFromCache:server];
}

- (void)removeAllServers
{
    NSArray *names = self.serversCache.allKeys;
    if (names.count == 0) return;
    
    [self.data removeKeys:names];
    [self.data synchronize];

    [self clearCache];
}



#pragma mark Private

- (void)addToCache:(PGServer *)server
{
    if (!server) return;
    self.namesCache[server.uid] = server.name;
    self.serversCache[server.name] = server;
    
    self.serversOrderedByName = nil;
}
- (void)removeFromCache:(PGServer *)server
{
    if (!server) return;
    NSString *nameInCache = self.namesCache[server.uid];
    [self.namesCache removeObjectForKey:server.uid];
    if (nameInCache) [self.serversCache removeObjectForKey:nameInCache];

    self.serversOrderedByName = nil;
}
- (void)clearCache
{
    [self.namesCache removeAllObjects];
    [self.serversCache removeAllObjects];
    self.serversOrderedByName = nil;
}

- (NSString *)unusedServerNameWithPrefix:(NSString *)prefix
{
    if (!NonBlank(prefix)) return prefix;
    
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

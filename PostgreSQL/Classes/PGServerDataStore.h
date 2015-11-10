//
//  PGServers.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 11/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGServerController.h"
#import "PGServer.h"
#import "PGData.h"

#pragma mark - PGServerDataStore

/**
 * Loads and saves a list of servers using CFPreferences.
 */
@interface PGServerDataStore : NSObject

@property (nonatomic, weak) PGServerController *serverController;

/// List of saved servers, ordered by name
@property (nonatomic, strong, readonly) NSArray *servers;

/**
 * Reloads saved servers list
 */
- (void)loadServers;

/**
 * Ensures saved servers are synchronized to disk
 */
- (void)synchronize;

/**
 * @return server with the specified name or nil if name not found.
 */
- (PGServer *)serverWithName:(NSString *)name;

/**
 * Create a new server and add to saved server list.
 *
 * @return a new server with a unique name and empty settings
 */
- (PGServer *)addServer;

/**
 * Create a new server with specified name and add to saved server list.
 *
 * Note if another server exists with the same name, then (1), (2), (3), etc. is added to the name.
 *
 * @return a new server with the specified name and empty settings
 */
- (PGServer *)addServerWithName:(NSString *)name;

/**
 * Create a new server with specified name and settings, and add to saved server list.
 *
 * Note if another server exists with the same name, then (1), (2), (3), etc. is added to the name.
 *
 * @return a new server with the specified name and settings
 */
- (PGServer *)addServerWithName:(NSString *)name settings:(PGServerSettings *)settings;

/**
 * Save server to data store
 *
 * @return YES if succeeded
 */
- (BOOL)saveServer:(PGServer *)server;

/**
 * Remove the specified server from the saved server list.
 */
- (void)removeServer:(PGServer *)server;

/**
 * Remove all saved servers.
 */
- (void)removeAllServers;

@end

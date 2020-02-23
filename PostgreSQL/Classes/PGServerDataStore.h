//
//  PGServerDataStore.h
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

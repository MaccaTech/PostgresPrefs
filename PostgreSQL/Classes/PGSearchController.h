//
//  PGSearchController.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 16/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGServerController.h"
#import "PGServer.h"
#import "PGLaunchd.h"
#import "PGProcess.h"

@class PGSearchController;

#pragma mark - PGSearchDelegate

/**
 * Delegate notified when search is finished.
 */
@protocol PGSearchDelegate <NSObject>
@required
- (void)didFindMoreServers:(PGSearchController *)search;
@end



#pragma mark - PGSearch

/**
 * Searches for existing PostgreSQL installations
 */
@interface PGSearchController : NSObject

@property (nonatomic, strong, readonly) NSArray *servers;

@property (nonatomic, weak) id<PGSearchDelegate> delegate;
@property (nonatomic, weak) PGServerController *serverController;

/**
 * Searches for installed servers. Runs in background as uses spotlight, and returns results to delegate.
 */
- (void)findInstalledServers;

/**
 * @return Finds all servers either loaded in launchd or running as independent processes.
 */
- (NSArray *)startedServers;

@end

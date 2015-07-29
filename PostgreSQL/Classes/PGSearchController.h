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
 * Searches for installed servers in background. Results returned to delegate.
 */
- (void)findInstalledServers;

/**
 * Searches for loaded servers in background. Results returned in callback.
 */
- (void)findLoadedServers:(void(^)(NSArray *servers))found authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;

@end

//
//  PGSearchController.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 16/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGServer.h"
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

- (id)initWithDelegate:(id<PGSearchDelegate>)delegate;

/**
 * Runs server search in background
 */
- (void)startFindServers;

@end

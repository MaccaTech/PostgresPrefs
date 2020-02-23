//
//  PGSearchController.h
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

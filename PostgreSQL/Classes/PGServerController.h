//
//  PGServerController.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 7/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SecurityFoundation/SFAuthorization.h>
#import "PGServer.h"
#import "PGLaunchd.h"
#import "PGProcess.h"

#pragma mark - Constants

extern NSString *const PGServerCheckStatusName;
extern NSString *const PGServerStartName;
extern NSString *const PGServerStopName;
extern NSString *const PGServerCreateName;
extern NSString *const PGServerDeleteName;

typedef NS_ENUM(NSInteger, PGServerAction) {
    PGServerCheckStatus = 0,
    PGServerStart,
    PGServerStop,
    PGServerDelete,
    PGServerCreate
};

CG_INLINE NSString *
ServerActionDescription(PGServerAction value)
{
    switch (value) {
        case PGServerCheckStatus: return PGServerCheckStatusName;
        case PGServerStart: return PGServerStartName;
        case PGServerStop: return PGServerStopName;
        case PGServerCreate: return PGServerCreateName;
        case PGServerDelete: return PGServerDeleteName;
    }
}



#pragma mark - PGServerDelegate

/**
 * A delegate that is notified when actions (start/stop/check status) are run on Postgre
 * Servers.
 */
@protocol PGServerDelegate <NSObject>
@required
- (void)didChangeServerStatus:(PGServer *)server;
- (void)postgreServer:(PGServer *)server willRunAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didRunAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didSucceedAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error;
@optional
// None
@end



#pragma mark - PGServerController

/**
 * Controller for starting, stopping and checking status of a PostgreSQL Server. All actions are carried out using launchctl / launchd.
 *
 * Also handles creation of servers, and updating server properties, because there are a number of server properties that depend on other properties. This class ensures the derived properties get populated, and does validation.
 */
@interface PGServerController : NSObject

@property (nonatomic, weak) id<PGServerDelegate> delegate;

/// The rights needed to run server actions
@property (nonatomic, readonly) AuthorizationRights *authorizationRights;

/**
 * Runs the action on the PostgreSQL server using launchctl
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization;

/**
 * Runs the action on the PostgreSQL server using launchctl
 *
 * If succeeded (or failed) parameter is non-nil, then instead of notifying the delegate
 * on success (failure), it runs the succeeded block. Thus allows chaining of actions
 * with the final succeeded notification only being sent to delegate once all
 * chained actions are finished. Also allows easier handling of failures in some cases.
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization succeeded:(void(^)(void))succeeded failed:(void(^)(NSString *error))failed;

/**
 * Gets the loaded server from launchd with the specified name, or nil if not loaded.
 */
- (PGServer *)loadedServerWithName:(NSString *)name forRootUser:(BOOL)root authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Converts launchd daemon properties to a server, from a file.
 */
- (PGServer *)serverFromDaemon:(NSDictionary *)daemon file:(NSString *)file;

/**
 * Converts launchd daemon properties to a server, from a daemon loaded in launchd.
 */
- (PGServer *)serverFromDaemon:(NSDictionary *)daemon forRootUser:(BOOL)root;

/**
 * Converts a server to launchd daemon properties.
 */
- (NSDictionary *)daemonFromServer:(PGServer *)server;

/**
 * Converts standardised server properties to a server.
 */
- (PGServer *)serverFromProperties:(NSDictionary *)properties name:(NSString *)name;

/**
 * Converts a server to standardised server properties.
 */
- (NSDictionary *)propertiesFromServer:(PGServer *)server;

/**
 * Creates server from manually-constructed settings
 */
- (PGServer *)serverFromSettings:(PGServerSettings *)settings name:(NSString *)name domain:(NSString *)domain;

/**
 * Checks settings and marks invalid as appropriate
 */
- (void)validateServerSettings:(PGServerSettings *)settings;

/**
 * Sets the server name, and makes any required changes to other properties.
 */
- (BOOL)setName:(NSString *)name forServer:(PGServer *)server;

/**
 * Sets the server startup, and makes any required changes to other properties.
 */
- (BOOL)setStartup:(PGServerStartup)startup forServer:(PGServer *)server;

/**
 * Sets the dirty value for a settings, and updates dirty flag.
 */
- (void)setDirtySetting:(NSString *)setting value:(NSString *)value forServer:(PGServer *)server;

/**
 * Sets the server dirty settings, and makes any required changes to otehr properties.
 */
- (void)setDirtySettings:(PGServerSettings *)settings forServer:(PGServer *)server;

/**
 * Sets the server settings, ane makes any required changes to other properties.
 */
- (void)setSettings:(PGServerSettings *)settings forServer:(PGServer *)server;

/**
 * Makes the dirty settings equal to the active settings, and sets dirty flag to NO
 */
- (void)clean:(PGServer *)server;

/**
 * @return YES if can check server status, because either have authorization or server doesn't need it
 */
- (BOOL)shouldCheckStatusForServer:(PGServer *)server authorization:(AuthorizationRef)authorization;

@end

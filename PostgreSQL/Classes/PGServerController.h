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
#import "PGProcess.h"

#pragma mark - Constants

extern NSString *const PGServerCheckStatusName;
extern NSString *const PGServerQuickStatusName;
extern NSString *const PGServerStartName;
extern NSString *const PGServerStopName;
extern NSString *const PGServerCreateName;
extern NSString *const PGServerDeleteName;

typedef NS_ENUM(NSInteger, PGServerAction) {
    PGServerCheckStatus = 0,
    PGServerQuickStatus,
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
        case PGServerQuickStatus: return PGServerQuickStatusName;
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
- (void)postgreServer:(PGServer *)server willRunAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didRunAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didSucceedAction:(PGServerAction)action;
- (void)postgreServer:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error;
@optional
// None
@end



#pragma mark - PGServerController

/**
 * Controller for starting, stopping and checking status of a Postgre Server.
 */
@interface PGServerController : NSObject

@property (nonatomic, weak) id<PGServerDelegate> delegate;

/// The rights needed to run server actions
@property (nonatomic, readonly) AuthorizationRights *authorizationRights;

- (id)initWithDelegate:(id<PGServerDelegate>)delegate;

/**
 * Runs pg_ctl with the action for the server
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization;

/**
 * Runs pg_ctl with the action for the server.
 *
 * If succeeded (or failed) parameter is non-nil, then instead of notifying the delegate
 * on success (failure), it runs the succeeded block. Thus allows chaining of actions
 * with the final succeeded notification only being sent to delegate once all
 * chained actions are finished. Also allows easier handling of failures in some cases.
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server authorization:(AuthorizationRef)authorization succeeded:(void(^)(void))succeeded failed:(void(^)(NSString *error))failed;

@end

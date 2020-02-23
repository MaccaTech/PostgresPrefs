//
//  PGServerController.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 7/7/15.
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
#import <SecurityFoundation/SFAuthorization.h>
#import "PGServer.h"
#import "PGLaunchd.h"
#import "PGProcess.h"
#import "PGFile.h"

#pragma mark - Constants

extern NSString *const PGServerCheckStatusName;
extern NSString *const PGServerStartName;
extern NSString *const PGServerStopName;
extern NSString *const PGServerCreateName;
extern NSString *const PGServerDeleteName;
extern NSString *const PGServerCheckStatusVerb;
extern NSString *const PGServerStartVerb;
extern NSString *const PGServerStopVerb;
extern NSString *const PGServerCreateVerb;
extern NSString *const PGServerDeleteVerb;

typedef NS_ENUM(NSInteger, PGServerAction) {
    PGServerCheckStatus = 0,
    
    /// Restart the server. Internal servers: validate settings, recreate plist file, create log file
    PGServerStart,
    
    /// Stop the server
    PGServerStop,
    
    /// Stop the server then delete the plist file
    PGServerDelete,
    
    /// Recreate the plist file
    PGServerCreate
};

static inline NSString *
NSStringFromPGServerAction(PGServerAction value)
{
    switch (value) {
        case PGServerCheckStatus: return PGServerCheckStatusName;
        case PGServerStart: return PGServerStartName;
        case PGServerStop: return PGServerStopName;
        case PGServerCreate: return PGServerCreateName;
        case PGServerDelete: return PGServerDeleteName;
    }
}

static inline NSString *
NSStringFromPGServerActionVerb(PGServerAction value)
{
    switch (value) {
        case PGServerCheckStatus: return PGServerCheckStatusVerb;
        case PGServerStart: return PGServerStartVerb;
        case PGServerStop: return PGServerStopVerb;
        case PGServerCreate: return PGServerCreateVerb;
        case PGServerDelete: return PGServerDeleteVerb;
    }
}



#pragma mark - PGServerDelegate

/**
 * A delegate that is notified when actions (start/stop/check status) are run on Postgre
 * Servers.
 */
@protocol PGServerDelegate <NSObject>
- (void)server:(PGServer *)server willRunAction:(PGServerAction)action;
- (void)server:(PGServer *)server didRunAction:(PGServerAction)action;
- (void)server:(PGServer *)server didSucceedAction:(PGServerAction)action;
- (void)server:(PGServer *)server didFailAction:(PGServerAction)action error:(NSString *)error;
@end



#pragma mark - PGServerController

/**
 * Controller for starting, stopping and checking status of a PostgreSQL Server. All actions are carried out using launchctl / launchd.
 *
 * Also handles creation of servers, and updating server properties, because there are a number of server properties that depend on other properties. This class ensures the derived properties get populated, and does validation.
 */
@interface PGServerController : NSObject

@property (nonatomic, weak) id<PGServerDelegate> delegate;

/// The rights required to perform controller actions
@property (nonatomic, readonly) PGRights *rights;

/**
 * Runs the action on the PostgreSQL server using launchctl
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server auth:(PGAuth *)auth;

/**
 * Runs the action on the PostgreSQL server using launchctl
 *
 * If succeeded (or failed) parameter is non-nil, then instead of notifying the delegate
 * on success (failure), it runs the succeeded block. Thus allows chaining of actions
 * with the final succeeded notification only being sent to delegate once all
 * chained actions are finished. Also allows easier handling of failures in some cases.
 */
- (void)runAction:(PGServerAction)action server:(PGServer *)server auth:(PGAuth *)auth succeeded:(void(^)(void))succeeded failed:(void(^)(NSString *error))failed;

/**
 * Lookup up a server running on the system by pid.
 */
- (PGServer *)runningServerWithPid:(NSInteger)pid;

/**
 * Lookup up a server loaded in launchd by name.
 */
- (PGServer *)loadedServerWithName:(NSString *)name forRootUser:(BOOL)root;

/**
 * Converts running process to a server.
 */
- (PGServer *)serverFromProcess:(PGProcess *)process;

/**
 * Converts launchd daemon properties to a server, from a file.
 */
- (PGServer *)serverFromDaemonFile:(NSString *)file;

/**
 * Converts launchd daemon properties to a server, from a daemon loaded in launchd.
 */
- (PGServer *)serverFromLoadedDaemon:(NSDictionary *)daemon forRootUser:(BOOL)root;

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

@end

//
//  PostgrePrefsDelegate.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 18/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGPrefsPane.h"
#import "NSString+Utilities.h"
#import "NSDictionary+Utilities.h"

#pragma mark - Constants

typedef NS_ENUM(NSInteger, PGPrefsStatus) {
    PGPrefsStatusUnknown = 0,
    PGPrefsStopped,
    PGPrefsStarted
};



#pragma mark - PGPrefsController

@interface PGPrefsController: NSObject <PGPrefsPaneDelegate>

@property (nonatomic, readonly) PGPrefsStatus status;

- (void)postgrePrefsDidAuthorize:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidDeauthorize:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidLoad:(PGPrefsPane *) prefs;
- (void)postgrePrefsWillUnselect:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidClickStartStopServer:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidClickRefresh:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidClickAutoStartup:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidClickResetSettings:(PGPrefsPane *) prefs;
- (void)postgrePrefsDidFinishEditingSettings:(PGPrefsPane *)prefs;

@end

//
//  PGRights.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 27/08/2015.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A wrapper around an AuthorizationRights strut.
 *
 * Facilitates passing AuthorizationRights as method parameters, because passing a simple pointer
 * to an AuthorizationRights could result in a crash.
 *
 * Provides a way of collecting rights from multiple sources and combining into one
 * set of rights.
 */
@interface PGRights : NSObject
/**
 * Pointer to the authorization rights struct.
 *
 * Any attempt to access the returned rights after this object is dealloc'd will result in a crash.
 */
- (AuthorizationRights *)authorizationRights;

/**
 * Checks if the authorization has the required rights.
 */
- (BOOL)authorized:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus;

/**
 * Instantiate with just one right.
 */
+ (PGRights *)rightsWithRightName:(NSString *)rightName value:(NSString *)rightValue;

/**
 * Instantiate with multiple rights.
 */
+ (PGRights *)rightsWithArrayOfRights:(NSArray *)array;
@end

//
//  PGRights.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 27/08/2015.
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
 * Instantiate with just one right.
 */
+ (PGRights *)rightsWithRightName:(NSString *)rightName value:(NSString *)rightValue;

/**
 * Instantiate with multiple rights.
 */
+ (PGRights *)rightsWithArrayOfRights:(NSArray *)array;

@end



#pragma mark - PGAuth

@class PGAuth;

typedef NSString * PGAuthReasonKey NS_EXTENSIBLE_STRING_ENUM;
extern PGAuthReasonKey PGAuthReasonAction;
extern PGAuthReasonKey PGAuthReasonTarget;

/**
 Provides authorization using a password prompt.
 */
@protocol PGAuthDelegate
- (AuthorizationRef)authorize:(PGAuth *)auth;
@end

/**
 Asks the delegate only once for authorization.
 */
@interface PGAuth : NSObject
@property (nonatomic, readonly) BOOL requested;
@property (nonatomic, readonly) OSStatus status;
@property (nonatomic, weak) id<PGAuthDelegate> delegate;
/// Passed to the delegate when authorization is required, so that the delegate
/// can inform the user why they need to provide their password.
@property (nonatomic, strong) NSDictionary<PGAuthReasonKey,NSString *> *reason;

- (instancetype)initWithDelegate:(id<PGAuthDelegate>)delegate;
- (AuthorizationRef)authorize:(PGRights *)rights;
- (AuthorizationRef)authorize:(PGRights *)rights reason:(NSDictionary<PGAuthReasonKey,NSString *> *)reason;
- (void)invalidate:(OSStatus)status;
@end



#pragma mark - PGUser

/**
 Username validation and lookup
 */
@interface PGUser : NSObject
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, readonly) NSInteger uid;
@property (nonatomic, readonly) BOOL isOtherUser;
@property (nonatomic, readonly) BOOL isRootUser;

@property (class, nonatomic, strong, readonly) PGUser *current;
@property (class, nonatomic, strong, readonly) PGUser *root;

- (instancetype)init NS_UNAVAILABLE;
/// Case-insensitive check  if username matches this user.
- (BOOL)hasUsername:(NSString *)username;
/// Get the user matching the username, or nil if doesn't exist.
+ (PGUser *)userWithUsername:(NSString *)user;
/// Convenience to check if users are equal. If either user is nil, assumed to be current user.
+ (BOOL)isSameUser:(PGUser *)user1 as:(PGUser *)user2;
@end

//
//  PGRights.m
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

#import "PGRights.h"

PGAuthReasonKey PGAuthReasonAction = @"PGAuthReasonAction";
PGAuthReasonKey PGAuthReasonTarget = @"PGAuthReasonTarget";

#pragma mark - Interfaces

@interface NSString (CaseInsensitive)
- (BOOL)isEqualToStringCaseInsensitive:(NSString *)aString;
@end

@interface PGRight : NSObject {
@public
    NSString *_value;
}
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *value;
@property (nonatomic, strong, readonly) NSString *key;
- (id)initWithName:(NSString *)name value:(NSString *)value;
@end

@interface PGRights () {
    AuthorizationRights _rights;
    AuthorizationItem *_items;
}
@property (nonatomic, strong, readonly) NSSet *rightSet;
@end

@interface PGAuth () {
    AuthorizationRef _authorization;
}
@end

@interface PGUser ()
- (instancetype)initWithUsername:(NSString *)username;
@end


#pragma mark - NSString

@implementation NSString (CaseInsensitive)
- (BOOL)isEqualToStringCaseInsensitive:(NSString *)aString
{
    return [self compare:aString options:NSCaseInsensitiveSearch] == NSOrderedSame;
}
@end


#pragma mark - PGRight

@implementation PGRight
- (id)initWithName:(NSString *)name value:(NSString *)value
{
    self = [super init];
    if (self) {
        _name = name;
        _value = value;
        _key = [NSString stringWithFormat:@"%@.%@", name, value?:@"*"];
    }
    return self;
}
- (BOOL)isEqual:(id)other
{
    if (self == other) return YES;
    return [_key isEqualToString:((PGRight *)other)->_key];
}
- (NSUInteger)hash
{
    return _key.hash;
}
@end



#pragma mark - PGRights

@implementation PGRights
- (id)init
{
    return [self initWithRightSet:nil];
}
- (id)initWithRightSet:(NSSet *)rightSet
{
    self = [super init];
    if (self) {
        int count = (int) rightSet.count;
        AuthorizationItem *items = malloc(sizeof(AuthorizationItem) * count);
        int i = 0;
        for (PGRight *right in rightSet) {
            AuthorizationItem item = {right.name.UTF8String, right.value.length, &(right->_value), 0};
            items[i] = item;
            i++;
        }
        AuthorizationRights rights = {count, items};
        _items = items;
        _rights = rights;
        _rightSet = rightSet;
    }
    return self;
}
- (AuthorizationRights *)authorizationRights;
{
    return &_rights;
}
- (void)dealloc
{
    if (_items) free(_items);
}
+ (PGRights *)rightsWithRightName:(NSString *)name value:(NSString *)value
{
    NSSet *rightSet = [NSSet setWithArray:@[[[PGRight alloc] initWithName:name value:value]]];
    return [[PGRights alloc] initWithRightSet:rightSet];
}
+ (PGRights *)rightsWithArrayOfRights:(NSArray *)array
{
    NSMutableSet *rightSet = [NSMutableSet set];
    for (PGRights *rights in array) {
        if (![rights isKindOfClass:[PGRights class]]) continue;
        [rightSet addObjectsFromArray:rights.rightSet.allObjects];
    }
    return [[PGRights alloc] initWithRightSet:[NSSet setWithSet:rightSet]];
}

@end



#pragma mark - PGAuth

@implementation PGAuth
- (instancetype)initWithDelegate:(id<PGAuthDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _status = errAuthorizationSuccess;
    }
    return self;
}
- (AuthorizationRef)authorize:(PGRights *)rights
{
    return [self authorize:rights reason:nil];
}
- (AuthorizationRef)authorize:(PGRights *)rights reason:(NSDictionary<PGAuthReasonKey,NSString *> *)reason
{
    if (reason) { _reason = reason; }
    if (!_requested) {
        _requested = YES;
        AuthorizationRef authorization = _authorization = [_delegate authorize:self];
        _status = authorization ? errAuthorizationSuccess : errAuthorizationCanceled;
    }
    
    if (_status == errAuthorizationSuccess) {
        AuthorizationRef authRef = _authorization;
        if (!authRef) {
            _status = errAuthorizationInvalidRef;
        } else {
            _status = AuthorizationCopyRights(authRef, rights.authorizationRights, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, NULL);
        }
    }

    return _status == errAuthorizationSuccess ? _authorization : NULL;
}
- (void)invalidate:(OSStatus)status
{
    _requested = YES;
    if (_status == errAuthorizationSuccess) {
        _status = status == errAuthorizationSuccess ? errAuthorizationInternal : status;
    }
}
- (NSString *)description
{
    switch (_status) {
        case errAuthorizationSuccess: return @"Authorized";
        case errAuthorizationInvalidRef: return @"Not Authorized";
        case errAuthorizationCanceled: return @"Authorization Cancelled";
        default: return @"Authorization Failed";
    }
}
@end



#pragma mark - PGUser

@implementation PGUser
- (instancetype)initWithUsername:(NSString *)username
{
    self = [super init];
    if (self) {
        _username = username;
    }
    return self;
}

- (BOOL)isOtherUser { return ![_username isEqualToString:NSUserName()]; }
- (BOOL)isRootUser { return [_username isEqualToString:@"root"]; }

- (NSInteger)uid
{
    if (self.isRootUser) { return 0; }

    __block NSInteger result = NSNotFound;
    [PGUser queryUser:_username resultsHandler:^(CSIdentityRef identity) {
        result = (NSInteger) CSIdentityGetPosixID(identity);
    }];
    return result < 0 ? NSNotFound : result;
}
- (BOOL)hasUsername:(NSString *)username
{
    return [_username isEqualToStringCaseInsensitive:username];
}
- (BOOL)isEqualTo:(id)object
{
    if (self == object) { return YES; }
    if (!object) { return NO; }
    if (![object isKindOfClass:[self class]]) { return NO; }
    return [self.username isEqualTo:((PGUser *) object).username];
}
- (NSString *)description
{
    return _username;
}

+ (BOOL)isSameUser:(PGUser *)user1 as:(PGUser *)user2
{
    if (!user1) { return !user2.isOtherUser; }
    if (!user2) { return !user1.isOtherUser; }
    return [user1 isEqualTo:user2];
}

+ (PGUser *)current
{
    return [[PGUser alloc] initWithUsername:NSUserName()];
}
+ (PGUser *)root
{
    static PGUser *result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [[PGUser alloc] initWithUsername:@"root"];
    });
    return result;
}
+ (PGUser *)userWithUsername:(NSString *)user
{
    user = TrimToNil(user);
    if (!user) { return self.current; }
    if ([user isEqualToStringCaseInsensitive:NSUserName()]) { return self.current; }
    if ([user isEqualToStringCaseInsensitive:@"root"]) { return self.root; }
    
    __block NSString *username = nil;
    [self queryUser:user resultsHandler:^(CSIdentityRef identity) {
        username = CFBridgingRelease(CSIdentityGetPosixName(identity));
    }];
    return username ? [[PGUser alloc] initWithUsername:username] : nil;
}

+ (void)queryUser:(NSString *)user resultsHandler:(void(^)(CSIdentityRef identity))resultsHandler
{
    CSIdentityQueryRef query = CSIdentityQueryCreateForName(NULL, (__bridge CFStringRef)(user), kCSIdentityQueryStringEquals, kCSIdentityClassUser, CSGetLocalIdentityAuthority());

    CSIdentityQueryExecute(query, 0, NULL);
    CFArrayRef results = CSIdentityQueryCopyResults(query);
    
    long numResults = CFArrayGetCount(results);
    if (numResults > 0) {
        CSIdentityRef identity = (CSIdentityRef) CFArrayGetValueAtIndex(results, 0);
        resultsHandler(identity);
    } else {
        DLog(@"User '%@' not found!", user);
    }

    CFRelease(results);
    CFRelease(query);
}
@end

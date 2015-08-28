//
//  PGRights.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 27/08/2015.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import "PGRights.h"

@interface PGRight : NSObject {
@public
    NSString *_value;
}
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *value;
@property (nonatomic, strong, readonly) NSString *key;
- (id)initWithName:(NSString *)name value:(NSString *)value;
@end

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

@interface PGRights() {
    AuthorizationRights _rights;
    AuthorizationItem *_items;
}
@property (nonatomic, strong, readonly) NSSet *rightSet;
@end

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
- (BOOL)authorized:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus
{
    OSStatus status;
    if (!authorization) status = errAuthorizationInvalidRef;
    else status = AuthorizationCopyRights(authorization, self.authorizationRights, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, NULL);
    if (authStatus) *authStatus = status;
    return status == errAuthorizationSuccess;
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

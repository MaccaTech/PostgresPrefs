//
//  Common.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#ifndef PostgreSQL_Common_h
#define PostgreSQL_Common_h

#define weakify(var) __weak typeof(var) org_postgresql_##var = var
#define strongify(var) __strong typeof(var) var = org_postgresql_##var

/// Run block on main thread
CG_INLINE void
MainThread(void(^block)(void))
{
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}
/// Run block in background thread
CG_INLINE void
BackgroundThread(void(^block)(void))
{
    if (![NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), block);
}
/// Run block in background thread after a delay
CG_INLINE void
BackgroundThreadAfterDelay(NSTimeInterval delay, void(^block)(void))
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), block);
}
/// Return value converted to NSString
CG_INLINE NSString *
ToString(id value)
{
    if (value == nil || value == [NSNull null]) return nil;
    return [value description];
}
/// Return value converted to NSArray
CG_INLINE NSArray *
ToArray(id value)
{
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSArray class]]) return nil;
    return (NSArray *)value;
}
/// Return value converted to NSDictionary
CG_INLINE NSDictionary *
ToDictionary(id value)
{
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSDictionary class]]) return nil;
    return (NSDictionary *)value;
}
/// Return value converted to BOOL
CG_INLINE BOOL
ToBOOL(id value)
{
    if (value == nil || value == [NSNull null]) return NO;
    if ([value isKindOfClass:[NSNumber class]]) return [((NSNumber *) value) boolValue];
    NSString *description = [[value description] lowercaseString];
    return [description isEqualToString:@"true"] || [description isEqualToString:@"yes"];
}
/// Return string with leading & trailing whitespace removed, or nil if only whitespace
CG_INLINE NSString *
TrimToNil(NSString *string)
{
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [trimmed length] > 0 ? trimmed : nil;
}
/// Return YES if the string is non-blank
CG_INLINE BOOL
NonBlank(NSString *string)
{
    static NSCharacterSet *NonBlanks;
    if (!NonBlanks) NonBlanks = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return string && [string rangeOfCharacterFromSet:NonBlanks].location != NSNotFound;
}
/// Return YES if both nil or equal
CG_INLINE BOOL
BothNilOrEqual(id a, id b)
{
    return a == b || [a isEqual:b];
}
/// Convert JSON string to dictionary. If JSON string is array, returns first element.
CG_INLINE NSDictionary *
JsonToDictionary(NSString *json, NSString **error)
{
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id jsonSerialized = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
    if (error) *error = jsonError ? [jsonError description] : nil;
    if (jsonError) return nil;
    if ([jsonSerialized isKindOfClass:[NSArray class]])
        jsonSerialized = ((NSArray *)jsonSerialized).firstObject;
    return ToDictionary(jsonSerialized);
}
/// Check if file exists
CG_INLINE BOOL
FileExists(NSString *path)
{
    if (!NonBlank(path)) return NO;
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:[path stringByExpandingTildeInPath] isDirectory:&isDirectory] && !isDirectory;
}
/// Check if dir exists
CG_INLINE BOOL
DirExists(NSString *path)
{
    if (!NonBlank(path)) return NO;
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:[path stringByExpandingTildeInPath] isDirectory:&isDirectory] && isDirectory;
}

#endif /* PostgreSQL_Common_h */

//
//  Common.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 4/7/15.
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

#ifndef PostgreSQL_Common_h
#define PostgreSQL_Common_h

#define weakify(var) __weak typeof(var) org_postgresql_##var = var
#define strongify(var) __strong typeof(var) var = org_postgresql_##var

// Assert called from main thread
#ifdef DEBUG
#define mustBeMainThread() assert([NSThread isMainThread])
#else
#define mustBeMainThread()
#endif

/// Run block on main thread
static inline void
MainThread(dispatch_block_t block)
{
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}
/// Run block on main  thread after a delay
static inline void
MainThreadAfterDelay(NSTimeInterval delay, dispatch_block_t block)
{
    if (delay <= 0) dispatch_async(dispatch_get_main_queue(), block);
    else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}
/// Run block in background thread
static inline void
BackgroundThread(dispatch_block_t block)
{
    if (![NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), block);
}
/// Run block in background thread after a delay
static inline void
BackgroundThreadAfterDelay(NSTimeInterval delay, dispatch_block_t block)
{
    if (delay <= 0) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), block);
    else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), block);
}
/// Return value converted to NSString
static inline NSString *
ToString(id value)
{
    if (value == nil || value == [NSNull null]) return nil;
    return [value description];
}
/// Return value converted to NSArray
static inline NSArray *
ToArray(id value)
{
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSArray class]]) return nil;
    return (NSArray *)value;
}
/// Return value converted to NSDictionary
static inline NSDictionary *
ToDictionary(id value)
{
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSDictionary class]]) return nil;
    return (NSDictionary *)value;
}
/// Return value converted to BOOL
static inline BOOL
ToBOOL(id value)
{
    if (value == nil || value == [NSNull null]) return NO;
    if ([value isKindOfClass:[NSNumber class]]) return [((NSNumber *) value) boolValue];
    NSString *description = [[value description] lowercaseString];
    return [description isEqualToString:@"true"] || [description isEqualToString:@"yes"];
}
/// Return string with leading & trailing whitespace removed, or nil if only whitespace
static inline NSString *
TrimToNil(NSString *string)
{
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [trimmed length] > 0 ? trimmed : nil;
}
/// Return YES if the string is non-blank
static inline BOOL
NonBlank(NSString *string)
{
    static NSCharacterSet *NonBlanks;
    if (!NonBlanks) NonBlanks = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return string && [string rangeOfCharacterFromSet:NonBlanks].location != NSNotFound;
}
/// Return YES if both nil or equal
static inline BOOL
BothNilOrEqual(id a, id b)
{
    return a == b || [a isEqual:b];
}
/// Convert JSON string to dictionary. If JSON string is array, returns first element.
static inline NSDictionary *
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

#endif /* PostgreSQL_Common_h */

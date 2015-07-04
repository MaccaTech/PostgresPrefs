//
//  NSDictionary+Utilities.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 HK Web Entrepreneurs. All rights reserved.
//

#import "NSDictionary+Utilities.h"

@implementation NSDictionary (Utilities)

- (BOOL)nonBlank
{
    for (id value in self.allValues) {
        if (value == [NSNull null]) return YES;
        if (! [value isKindOfClass:[NSString class]]) return YES;
        if ( ((NSString *) value).nonBlank ) return YES;
    }
    
    return NO;
}
- (NSDictionary *)stringDictionary
{
    if (!self) return self;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:self];
    for (id key in self.allKeys) {
        id value = self[key];
        NSString *stringValue = nil;
        if (!value || value == [NSNull null]) stringValue = @"";
        else stringValue = [[value description] trimToNil] ?: @"";
        if (![stringValue isEqual:value]) result[key] = stringValue;
    }
    return result;
}

@end

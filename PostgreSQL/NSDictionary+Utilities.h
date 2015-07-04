//
//  NSDictionary+Utilities.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 HK Web Entrepreneurs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+Utilities.h"

@interface NSDictionary (Utilities)

/**
 * Check if dictionary is non-blank, i.e. contains values other than
 * blank strings (including [NSNULL null] values)
 *
 * @return YES if dictionary contains values other than blank strings
 */
- (BOOL)nonBlank;

/**
 * Create a copy of this dictionary with only trimmed string-values.
 *
 * @return a copy of this dictionary with all values as trimmed strings, with [NSNull null] replaced with the empty string
 */
- (NSDictionary *)stringDictionary;

@end

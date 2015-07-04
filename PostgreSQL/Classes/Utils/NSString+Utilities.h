//
//  NSString+Utilities.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 4/7/15.
//  Copyright (c) 2015 HK Web Entrepreneurs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Utilities)

/**
 * @return YES if this string is non-blank
 */
- (BOOL)nonBlank;
/**
 * @return this string with leading & trailing whitespace removed, or nil if only whitespace
 */
- (NSString *)trimToNil;

/**
 * Runs this string as an unauthorized shell command with the specified args. Does not wait for output.
 */
- (void)startWithArgs:(NSArray *)args;
/**
 * Runs this string as an unauthorized shell command with the specified args. Returns output.
 */
- (NSString *)runWithArgs:(NSArray *)args;
/**
 * Runs this string as an authorized shell command with the specified args. Does not wait for output.
 */
- (void)startWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization;
/**
 * Runs this string as an authorized shell command with the specified args. Returns output.
 */
- (NSString *)runWithArgs:(NSArray *)args authorization:(AuthorizationRef)authorization;

@end

//
//  PGFile.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 26/08/2015.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGProcess.h"

/**
 * Access the file system with admin privileges.
 */
@interface PGFile : NSObject

/**
 * Checks if file exists.
 */
+ (BOOL)fileExists:(NSString *)file authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Checks if dir exists.
 */
+ (BOOL)dirExists:(NSString *)dir authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Writes a file using a string as its content.
 */
+ (BOOL)createFile:(NSString *)file contents:(NSString *)contents owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Writes a property list file using a dictionary as its content.
 */
+ (BOOL)createPlistFile:(NSString *)file contents:(NSDictionary *)contents owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Deletes a file.
 *
 * Silently ignores if path does not exist.
 */
+ (BOOL)deleteFile:(NSString *)file authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;

/**
 * Creates a dir with all required parent dirs.
 *
 * Silently ignores if path already exists.
 */
+ (BOOL)createDir:(NSString *)dir owner:(NSString *)owner authorization:(AuthorizationRef)authorization authStatus:(OSStatus *)authStatus error:(NSString **)error;
@end

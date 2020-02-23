//
//  PGFile.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 26/08/2015.
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
#import "PGProcess.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PGFileType) {
    PGFileNone = 0,
    PGFileFile,
    PGFileDir
};

static inline NSString *
NSStringFromPGFileType(PGFileType type)
{
    switch (type) {
        case PGFileNone: return @"none";
        case PGFileFile: return @"file";
        case PGFileDir: return @"directory";
    }
};



#pragma mark - PGFile

/**
 Access the file system, optionally with admin privileges.
 */
@interface PGFile : NSObject

/// Determine if path is file or dir or nothing.
+ (PGFileType)typeOfFileAtPath:(nullable NSString *)path;

/// Determine if path is file or dir or nothing with optional authorization.
+ (PGFileType)typeOfFileAtPath:(nullable NSString *)path
                          auth:(nullable PGAuth *)authorization
                         error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Checks if file exists without authorization.
+ (BOOL)fileExists:(nullable NSString *)file;

/// Checks if file exists. Error if path is a directory or authorization fails.
+ (BOOL)fileExists:(nullable NSString *)file
              user:(nullable PGUser *)user
              auth:(nullable PGAuth *)auth
             error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Checks if dir exists without authorization.
+ (BOOL)dirExists:(nullable NSString *)dir;

/// Checks if dir exists. Error if path is a file or authorization fails.
+ (BOOL)dirExists:(nullable NSString *)dir
             user:(nullable PGUser *)user
             auth:(nullable PGAuth *)auth
            error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Creates a dir with all required parent dirs without authorization. Silently ignores if dir already exists.
+ (BOOL)createDir:(NSString *)dir
            error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Creates a dir with all required parent dirs. Silently ignores if dir already exists.
+ (BOOL)createDir:(NSString *)dir
             user:(nullable PGUser *)user
             auth:(nullable PGAuth *)auth
            error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Writes a file using a string as its content without authorization.
+ (BOOL)createFile:(NSString *)file
          contents:(nullable NSString *)contents
             error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Writes a file using a string as its content.
+ (BOOL)createFile:(NSString *)file
          contents:(nullable NSString *)contents
              user:(nullable PGUser *)user
              auth:(nullable PGAuth *)auth
             error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Writes a property list file using a dictionary as its content without authorization.
+ (BOOL)createPlistFile:(NSString *)file
               contents:(nullable NSDictionary *)contents
                  error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Writes a property list file using a dictionary as its content.
+ (BOOL)createPlistFile:(NSString *)file
               contents:(nullable NSDictionary *)contents
                   user:(nullable PGUser *)user
                   auth:(nullable PGAuth *)auth
                  error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Deletes a file without authorization. Silently ignores if path does not exist.
+ (BOOL)remove:(nullable NSString *)file
         error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Deletes a file. Silently ignores if path does not exist.
+ (BOOL)remove:(nullable NSString *)file
          auth:(nullable PGAuth *)auth
         error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Moves a file or dir without authorization.
+ (BOOL)move:(NSString *)oldPath
          to:(NSString *)newPath
       error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Moves a file or dir.
+ (BOOL)move:(NSString *)oldPath
          to:(NSString *)newPath
    fromUser:(nullable PGUser *)oldUser
      toUser:(nullable PGUser *)newUser
        auth:(nullable PGAuth *)auth
       error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Copies a file or dir without authorization.
+ (BOOL)copy:(NSString *)oldPath
          to:(NSString *)newPath
       error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Copies a file or dir.
+ (BOOL)copy:(NSString *)oldPath
          to:(NSString *)newPath
    fromUser:(nullable PGUser *)oldUser
      toUser:(nullable PGUser *)newUser
        auth:(nullable PGAuth *)auth
       error:(NSString *_Nullable __autoreleasing *_Nullable)error;

/// Allocate a temp file path without authorization. File is automatically deleted immediately.
+ (void)temporaryFileWithExtension:(NSString *)extension
                        usingBlock:(void(^)(NSString *tempPath))block;

@end

NS_ASSUME_NONNULL_END

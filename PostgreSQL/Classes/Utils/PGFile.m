//
//  PGFile.m
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

#import "PGFile.h"

#pragma mark - PGFile

@implementation PGFile

+ (NSFileManager *)fileManager
{
    return NSFileManager.defaultManager;
}

+ (NSString *)validatePath:(NSString *)path errorIfBlank:(BOOL)errorIfBlank error:(NSString *__autoreleasing *)outerr
{
    path = [TrimToNil(path) stringByExpandingTildeInPath];
    if (outerr) { *outerr = path || !errorIfBlank ? nil : @"Filename required!"; }
    return path;
}

+ (NSString *)inDir:(NSString *)path
{
    NSURL *result = [NSURL fileURLWithPath:path.stringByExpandingTildeInPath].absoluteURL;
    NSURL *previous = result;
    do {
        result = result.URLByDeletingLastPathComponent;
        if (result == previous) { break; }
        if (result.path.length == 0) { break; }
        previous = result;
    } while (![self.fileManager fileExistsAtPath:result.path]);
    return result.path;
}
+ (BOOL)inReadableDir:(NSString *)path
{
    return [self.fileManager isReadableFileAtPath:[self inDir:path]];
}
+ (BOOL)inWritableDir:(NSString *)path
{
    return [self.fileManager isWritableFileAtPath:[self inDir:path]];
}

+ (PGFileType)typeOfFileAtPath:(NSString *)path
{
    return [self typeOfFileAtPath:path auth:nil error:nil];
}
+ (PGFileType)typeOfFileAtPath:(NSString *)path auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    if (!(path = [self validatePath:path errorIfBlank:NO error:outerr])) {
        return PGFileNone;
    }
    
    // Try without authorization
    PGFileType result = PGFileNone;
    BOOL isDirectory = NO;
    BOOL exists = [self.fileManager fileExistsAtPath:path isDirectory:&isDirectory];
    
    // Found
    if (exists) {
        result = isDirectory ? PGFileDir : PGFileFile;
        if (outerr) { *outerr = nil; }

    // Not found
    } else {
        // Authorization required
        if (![self inReadableDir:path]) {
            NSString *command = [NSString stringWithFormat:@"path=\"%@\" && ([ -f \"$path\" ] && echo \"f\") || ([ -d \"$path\" ] && echo \"d\")", path];
            NSString *outout = nil;
            if ([PGProcess runShellCommand:command forRootUser:YES auth:auth output:&outout error:outerr]) {
                if ([outout hasPrefix:@"f"]) { result = PGFileFile; }
                else if ([outout hasPrefix:@"d"]) { result = PGFileDir; }
            }
        }
    }
    
    return result;
}
+ (BOOL)fileExists:(NSString *)file
{
    return [self fileExists:file user:nil auth:nil error:nil];
}
+ (BOOL)fileExists:(NSString *)file user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    PGFileType result = [self typeOfFileAtPath:file auth:auth error:outerr];
    switch (result) {
        case PGFileDir:
            if (outerr) { *outerr = [NSString stringWithFormat:@"Invalid file: %@", file]; }
            return NO;
        case PGFileNone: return NO;
        case PGFileFile: return YES;
    }
}

+ (BOOL)dirExists:(NSString *)dir
{
    return [self dirExists:dir user:nil auth:nil error:nil];
}
+ (BOOL)dirExists:(NSString *)dir user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    PGFileType result = [self typeOfFileAtPath:dir auth:auth error:outerr];
    switch (result) {
        case PGFileFile:
            if (outerr) { *outerr = [NSString stringWithFormat:@"Invalid dir: %@", dir]; }
            return NO;
        case PGFileNone: return NO;
        case PGFileDir: return YES;
    }
}

+ (BOOL)create:(PGFileType)type path:(NSString *)path contents:(NSString *)contents user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    if (type == PGFileNone) { return YES; }
    if (!(path = [self validatePath:path errorIfBlank:YES error:outerr])) {
        return NO;
    }
    
    // Try to create
    NSDictionary *attributes = !user.isOtherUser ? nil : @{NSFileOwnerAccountName:user.username};
    NSError *error = nil;
    BOOL result;
    if (type == PGFileFile) {
        // Parent dir must exist first
        if (![self createDir:path.stringByDeletingLastPathComponent user:user auth:auth error:outerr]) { return NO; }
        
        result = [self.fileManager createFileAtPath:path contents:[contents dataUsingEncoding:NSUTF8StringEncoding] attributes:attributes];
    } else {
        result = [self.fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:attributes error:&error];
    }
    
    // Failed
    if (!result) {
        BOOL needsAuth = user.isOtherUser;
        if (!needsAuth) needsAuth = ![self inWritableDir:path];
        
        // Authorization required
        if (needsAuth) {
            NSString *createCmd;
            if (type == PGFileFile) {
                createCmd = [NSString stringWithFormat:@"echo \"%@\" > \"%@\"", (contents?:@""), path];
            } else {
                createCmd = [NSString stringWithFormat:@"mkdir -p \"%@\"", path];
            }
            NSString *command = [NSString stringWithFormat:@"%@ && chown %@ \"%@\"", createCmd, user, path];
            result = [PGProcess runShellCommand:command forRootUser:YES auth:auth error:outerr];
        
        // Error
        } else {
            if (outerr) { *outerr = [NSString stringWithFormat:@"Failed to create file %@", path]; }
        }
    }
    
    return result;
}

+ (BOOL)createDir:(NSString *)dir error:(NSString *__autoreleasing *)error
{
    return [self createDir:dir user:nil auth:nil error:error];
}
+ (BOOL)createDir:(NSString *)dir user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self create:PGFileDir path:dir contents:nil user:user auth:auth error:error];
}

+ (BOOL)createFile:(NSString *)file contents:(NSString *)contents error:(NSString *__autoreleasing *)error
{
    return [self createFile:file contents:contents user:nil auth:nil error:error];
}
+ (BOOL)createFile:(NSString *)file contents:(NSString *)contents user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self create:PGFileFile path:file contents:contents user:user auth:auth error:error];
}

+ (BOOL)createPlistFile:(NSString *)file contents:(NSDictionary *)contents error:(NSString *__autoreleasing *)error
{
    return [self createPlistFile:file contents:contents user:nil auth:nil error:error];
}
+ (BOOL)createPlistFile:(NSString *)path contents:(NSDictionary *)contents user:(PGUser *)user auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    if (!(path = [self validatePath:path errorIfBlank:YES error:outerr])) {
        return NO;
    }
    if (!contents) { contents = @{}; }

    // Parent dir must exist
    if (![self createDir:path.stringByDeletingLastPathComponent user:user auth:auth error:outerr]) { return NO; }
    
    // Create plist as a temporary file, then move into place.
    __block BOOL result = NO;
    [self temporaryFileWithExtension:path.pathExtension usingBlock:^(NSString *temporaryPath) {
        
        // Write output to temporary file
        NSOutputStream *tempStream = [NSOutputStream outputStreamToFileAtPath:temporaryPath append:NO];
        [tempStream open];
        NSError *writeError = nil;
        NSInteger numberOfBytes = [NSPropertyListSerialization writePropertyList:contents toStream:tempStream format:NSPropertyListXMLFormat_v1_0 options:0 error:&writeError];
        
        // Write failed
        if (numberOfBytes == 0) {
            if (outerr) { *outerr = [NSString stringWithFormat:@"Error creating property file: %@", (writeError ?: [NSString stringWithFormat:@"invalid data or permissions for dir %@", path.stringByDeletingLastPathComponent])]; }
            
        // Move/copy temporary file to final location
        } else {
            result = [self move:temporaryPath to:path fromUser:nil toUser:user auth:auth error:outerr];
        }
    }];
    
    return result;
}
+ (void)temporaryFileWithExtension:(NSString *)extension usingBlock:(void(^)(NSString *temporaryPath))block
{
    // Note that the preferred method for getting a temporary directory
    // (URLForDirectory:inDomain:appropriateForURL:create:error:)
    // is unsuitable, because the returned directory is only visible by
    // the current user. We need a temporary directory that BOTH
    // the current user AND root can access. We need this because we are
    // creating .plist files that we'll move either to
    // ~/Library/LaunchAgents or to /Library/LaunchAgents (the former
    // being a user dir, the latter being a root dir).
    NSString *extensionWithDot = extension.length == 0 ? @"" : ([extension hasPrefix:@"."] ? extension : [@"." stringByAppendingString:extension]);
    NSString *filename = [NSString stringWithFormat:@"%@%@", [NSUUID UUID].UUIDString, extensionWithDot];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    block(path);
    NSString *error = nil;
    [self remove:path error:&error];
    if (IsLogging) { if (error) { DLog(error); } }
}

+ (BOOL)remove:(NSString *)path error:(NSString *__autoreleasing *)error
{
    return [self remove:path auth:nil error:error];
}
+ (BOOL)remove:(NSString *)path auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    if (!(path = [self validatePath:path errorIfBlank:NO error:outerr])) {
        return YES;
    }
    
    // Already deleted
    PGFileType type = [PGFile typeOfFileAtPath:path auth:auth error:outerr];
    if (IsLogging) {
        DLog(@"Type is '%@' for path: %@", NSStringFromPGFileType(type), path);
    }
    if (type == PGFileNone) {
        return YES;
    } else if (type == PGFileDir) {
        if (outerr) { *outerr = @"Removing directories not permitted!"; }
        return NO;
    }

    // Try without authorization
    NSError *error = nil;
    BOOL result = [self.fileManager removeItemAtPath:path error:&error];
    
    // Failed
    if (!result) {
        BOOL needsAuth = ![self inWritableDir:path];
        
        // Authorization required
        if (needsAuth) {
            NSString *command = [NSString stringWithFormat:@"rm \"%@\"", path];
            result = [PGProcess runShellCommand:command forRootUser:YES auth:auth error:outerr];

        // Error
        } else {
            if (outerr) { *outerr = [NSString stringWithFormat:@"Failed to delete file %@", path]; }
        }
    }
    
    return result;
}

+ (BOOL)copyWithMove:(BOOL)move from:(NSString *)from to:(NSString *)to fromUser:(PGUser *)fromUser toUser:(PGUser *)toUser auth:(PGAuth *)auth error:(NSString *__autoreleasing *)outerr
{
    from = [self validatePath:from errorIfBlank:YES error:outerr];
    to = [self validatePath:to errorIfBlank:YES error:outerr];
    if (!from || !to) { return NO; }
    
    // Try without authorization
    NSError *error = nil;
    BOOL result;
    if (![PGUser isSameUser:fromUser as:toUser]) {
        result = NO;
    } else {
        if (move) {
            result = [self.fileManager moveItemAtPath:from toPath:to error:&error];
        } else {
            result = [self.fileManager copyItemAtPath:from toPath:to error:&error];
        }
    }

    // Failed
    if (!result) {
        BOOL needsAuth = fromUser.isOtherUser || toUser.isOtherUser;
        if (!needsAuth) needsAuth = ![self inWritableDir:from];
        if (!needsAuth) needsAuth = ![self inWritableDir:to];

        // Authorization required
        if (needsAuth) {
            if (!toUser) { toUser = PGUser.current; }
            NSString *copyCmd = [NSString stringWithFormat:@"%@ \"%@\" \"%@\"", (move ? @"mv" : @"cp -R"), from, to];
            NSString *command = [NSString stringWithFormat:@"%@ && chown %@ \"%@\"", copyCmd, toUser, to];
            result = [PGProcess runShellCommand:command forRootUser:YES auth:auth error:outerr];

        // Error
        } else {
            if (outerr) { *outerr = [NSString stringWithFormat:@"Failed to %@ %@ to %@\n%@", (move ? @"move" : @"copy"), from, to, (error.description ?: @"Unknown error")]; }
        }
    }
    
    return result;
}

+ (BOOL)copy:(NSString *)oldPath to:(NSString *)newPath error:(NSString *__autoreleasing *)error
{
    return [self copy:oldPath to:newPath fromUser:nil toUser:nil auth:nil error:error];
}
+ (BOOL)copy:(NSString *)oldPath to:(NSString *)newPath fromUser:(PGUser *)oldUser toUser:(PGUser *)newUser auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self copyWithMove:NO from:oldPath to:newPath fromUser:oldUser toUser:newUser auth:auth error:error];
}
+ (BOOL)move:(NSString *)oldPath to:(NSString *)newPath error:(NSString *__autoreleasing *)error
{
    return [self move:oldPath to:newPath fromUser:nil toUser:nil auth:nil error:error];
}
+ (BOOL)move:(NSString *)oldPath to:(NSString *)newPath fromUser:(PGUser *)oldUser toUser:(PGUser *)newUser auth:(PGAuth *)auth error:(NSString *__autoreleasing *)error
{
    return [self copyWithMove:YES from:oldPath to:newPath fromUser:oldUser toUser:newUser auth:auth error:error];
}

@end

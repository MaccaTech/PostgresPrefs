//
//  PGPrefsUtilities.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 20/12/11.
//  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
//

#import <Foundation/Foundation.h>

// Running processes
NSString* runCommand(NSString* command, NSArray* args, BOOL waitForOutput);
NSString* runAuthorizedCommand(NSString* command, NSArray* args, AuthorizationRef authorization, BOOL waitForOutput);

// Utility functions
NSDictionary* mergeDictionaries(NSDictionary* dictionary, NSDictionary* other);
BOOL isNonBlankString(id value);
BOOL isBlankString(id string);
BOOL isBlankDictionary(NSDictionary* dictionary);
BOOL isEqualStringDictionary(NSDictionary *a, NSDictionary *b);

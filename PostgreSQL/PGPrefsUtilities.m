//
//  PGPrefsUtilities.m
//  PostgreSQL
//
//  Created by Francis McKenzie on 20/12/11.
//  Copyright (c) 2011 HK Web Entrepeneurs. All rights reserved.
//

#import "PGPrefsUtilities.h"

//
// Runs a command with no authorization and either returns output or returns immediately with no output
//
NSString* runCommand(NSString *command, NSArray *args, BOOL waitForOutput) {
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:command];
    if (args) {
        [task setArguments:args];
    }
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    //The magic line that keeps your log where it belongs
    [task setStandardInput:[NSPipe pipe]];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    // Log
    DLog(@"Running: %@", [[[NSArray arrayWithObjects:command, nil] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);

    // Run
    [task launch];
    
    if (waitForOutput) {
        [task waitUntilExit];
    }
     
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data
                                   encoding: NSUTF8StringEncoding];
    
    NSString *result;
    result = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [string release];
    [task release];
    
    if ([result length] == 0) {
        result = nil;
    }
    return result;
}

//
// Runs a shell command with authorization and either returns output or returns immediately with no output
//
NSString* runAuthorizedCommand(NSString *command, NSArray *args, AuthorizationRef authorization, BOOL waitForOutput) {
    // Convert command into const char*;
    const char *commandArg = strdup([command UTF8String]);
    
    // Convert args array into void-* array.
    const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
    int argvIndex = 0;
    if (args) {
        for (NSString *string in args) {
            // If we just using the returned UTF8String, strange things happen
            argv[argvIndex] = strdup([string UTF8String]);
            argvIndex++;
        }
    }
    argv[argvIndex] = nil;
    
    // Pipe for collecting output
    FILE *processOutput;
    processOutput = NULL;
    
    // Log
    DLog(@"Running Authorized: %@", [[[NSArray arrayWithObjects:command, nil] arrayByAddingObjectsFromArray:args] componentsJoinedByString:@" "]);
    
    // Run command with authorization
    FILE **processOutputRef = waitForOutput ? &processOutput : NULL;
    OSStatus processError = AuthorizationExecuteWithPrivileges(authorization, commandArg, kAuthorizationFlagDefaults, (char *const *)argv, processOutputRef);

    // Release command and args
    free(commandArg);
    if (args) {
        for (int i = 0; i < argvIndex; i++) {
            free(argv[i]);
        }
    }
    free(argv);
    
    // Get output
    NSString *result = nil;
    
    // Check for errors
    if (processError != errAuthorizationSuccess) {
        DLog(@"Error: %d", processError);

    // Only return output if no errors
    } else if (waitForOutput) {
            
        // Read the output from the FILE pipe up to EOF (or other error).
#define READ_BUFFER_SIZE 64
        char readBuffer[READ_BUFFER_SIZE];
        NSMutableString *processOutputString = [NSMutableString string];
        size_t charsRead;
        while ((charsRead = fread(readBuffer, 1, READ_BUFFER_SIZE, *processOutputRef)) != 0) {
            NSString *bufferString =
            [[NSString alloc]
             initWithBytes:readBuffer
             length:charsRead
             encoding:NSUTF8StringEncoding];
            [processOutputString appendString:bufferString];
            [bufferString release];
        }
        
        // Trim output
        result = [processOutputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([result length] == 0) {
            result = nil;
        }
    }
    
    // Close pipe
	fclose(processOutput);
    
    // Log
    if (waitForOutput) {
        DLog(@"Result: %@", result);
    } else {
        DLog(@"Done");
    }
    
    return result;
}

// Utility method - combine two dictionaries by adding contents of second if missing in first
//
NSDictionary* mergeDictionaries(NSDictionary *dictionary, NSDictionary *other) {
    
    // Create empty dictionary for results
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    
    // Add dictionaries - notice order
    if (other) {
        [result addEntriesFromDictionary:other];
    }
    if (dictionary) {
        [result addEntriesFromDictionary:dictionary];
    }
    
    // Return result
    [result autorelease];
    return result;
}

//
// Utility method - check if NSString is blank
//
BOOL isBlankString(id string) {
    if (string && string != [NSNull null]) {
        if ([string isKindOfClass:[NSString class]]) {
            return [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;
        } else {
            return NO;
        }
    }
    return YES;
}
    
//
// Utility method - check if NSString is non-blank
//
BOOL isNonBlankString(id value) {
    return (value && value != [NSNull null] && [value isKindOfClass:[NSString class]] && [value length] > 0);
}

//
// Utility method - check if dictionary is blank
//
BOOL isBlankDictionary(NSDictionary *dictionary) {
    if (dictionary) {
        for (id key in dictionary) {
            id value = [dictionary valueForKey:key];
            if (! isBlankString(value)) {
                return NO;
            }
        }
    }
    
    return YES;
}

//
// Utility method - check if dictionaries have equal string keys and values
//
BOOL isEqualStringDictionary(NSDictionary *a, NSDictionary *b) {
    if (!a || !b) {
        return (!a || !b ? YES : NO);
    } else {
        for (id key in a) {
            id aVal = [a valueForKey:key];
            id bVal = [b valueForKey:key];
            BOOL aIsStr = isNonBlankString(aVal);
            BOOL bIsStr = isNonBlankString(bVal);
            if (!aIsStr || !bIsStr) {
                return (!aIsStr && !bIsStr ? [aVal isEqual:bVal] : NO);
            } if (![aVal isEqualToString:bVal]) {
                return NO;
            }
        }
    }
    
    return YES;
}


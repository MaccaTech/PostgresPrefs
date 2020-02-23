//
//  PGData.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 11/7/15.
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

/**
 * Utility class for storing data using CFPreferences.
 *
 * The data is assumed to be stored in the form:
 *
 *     (string,dictionary) or
 *     (string,number) or
 *     (string,string)
 */
@interface PGData : NSObject

/// The name of the preferences file (e.g. com.mycompany.prefs)
@property (nonatomic, strong, readonly) NSString *appID;

/**
 * @param appID the name of the preferences file (e.g. com.mycompany.prefs)
 */
- (id)initWithAppID:(NSString *)appID;
/**
 * Gets all keys in CFPreferences
 */
- (NSArray *)allKeys;
/**
 * Loads all (string,dictionary) entries in CFPreferences
 *
 * @return dictionary of (string,dictionary) entries
 */
- (NSDictionary *)allData;
/**
 * Loads all (string,primitive) entries in CFPreferences
 * (Primitive means number or string)
 *
 * @return dictionary of (string,primitive) entries
 */
- (NSDictionary *)allPrimitives;
/**
 * Loads number for specified key in CFPreferences
 */
- (NSNumber *)numberForKey:(NSString *)key;
/**
 * Creates or overwrites number for specified key in CFPreferences
 */
- (void)setNumber:(NSNumber *)value forKey:(NSString *)key;
/**
 * Loads string for specified key in CFPreferences
 */
- (NSString *)stringForKey:(NSString *)key;
/**
 * Creates or overwrites string for specified key in CFPreferences
 */
- (void)setString:(NSString *)value forKey:(NSString *)key;
/**
 * Loads dictionary value for specified key in CFPreferences
 */
- (NSDictionary *)dataForKey:(NSString *)key;
/**
 * Creates or overwrites data for specified key in CFPreferences
 */
- (void)setData:(NSDictionary *)data forKey:(NSString *)key;
/**
 * Removes key in CFPreferences
 */
- (void)removeKey:(NSString *)key;
/**
 * Removes multiple keys in CFPreferences
 */
- (void)removeKeys:(NSArray *)keys;
/**
 * Synchronizes CFPreferences changes to disk
 */
- (void)synchronize;

@end

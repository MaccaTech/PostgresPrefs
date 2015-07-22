//
//  PGData.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 11/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
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

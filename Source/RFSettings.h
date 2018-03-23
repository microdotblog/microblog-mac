//
//  RFSettings.h
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RFAccount;

static NSString* const kExternalBlogIsPreferred = @"ExternalBlogIsPreferred";

@interface RFSettings : NSObject

+ (NSArray *) accounts; // RFAccount
+ (RFAccount *) defaultAccount;
+ (void) migrateSettings;

+ (BOOL) boolForKey:(NSString *)prefKey;
+ (BOOL) boolForKey:(NSString *)prefKey account:(RFAccount *)account;
+ (void) setBool:(BOOL)value forKey:(NSString *)prefKey account:(RFAccount *)account;

+ (NSString *) stringForKey:(NSString *)prefKey;
+ (NSString *) stringForKey:(NSString *)prefKey account:(RFAccount *)account;
+ (void) setString:(NSString *)value forKey:(NSString *)prefKey account:(RFAccount *)account;

@end

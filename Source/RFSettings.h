//
//  RFSettings.h
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RFAccount;

static NSString* const kCurrentUsername = @"CurrentUsername";
static NSString* const kAccountUsernames = @"AccountUsernames";

static NSString* const kExternalBlogIsPreferred = @"ExternalBlogIsPreferred";
static NSString* const kAccountUsername = @"AccountUsername";
static NSString* const kAccountFullName = @"AccountFullName";
static NSString* const kAccountDefaultSite = @"AccountDefaultSite";
static NSString* const kAccountEmail = @"AccountEmail";
static NSString* const kAccountGravatarURL = @"AccountGravatarURL";
static NSString* const kHasSnippetsBlog = @"HasSnippetsBlog";
static NSString* const kIsFullAccess = @"IsFullAccess";
static NSString* const kExternalMicropubState = @"ExternalMicropubState";
static NSString* const kExternalMicropubTokenEndpoint = @"ExternalMicropubTokenEndpoint";
static NSString* const kExternalMicropubMe = @"ExternalMicropubMe";
static NSString* const kExternalBlogUsername = @"ExternalBlogUsername";
static NSString* const kExternalBlogEndpoint = @"ExternalBlogEndpoint";
static NSString* const kExternalBlogID = @"ExternalBlogID";
static NSString* const kExternalBlogApp = @"ExternalBlogApp";
static NSString* const kExternalBlogURL = @"ExternalBlogURL";
static NSString* const kExternalMicropubPostingEndpoint = @"ExternalBlogURL";
static NSString* const kExternalMicropubMediaEndpoint = @"ExternalMediaURL";
static NSString* const kCurrentDestinationUID = @"CurrentDestinationUID";
static NSString* const kCurrentDestinationName = @"CurrentDestinationName";
static NSString* const kExternalBlogFormat = @"ExternalBlogFormat";
static NSString* const kExternalBlogCategory = @"ExternalBlogCategory";

@interface RFSettings : NSObject

+ (NSArray *) accounts; // RFAccount
+ (RFAccount *) defaultAccount;
+ (void) addAccount:(RFAccount *)account;
+ (void) removeAccount:(RFAccount *)account;
+ (void) migrateSettings;

+ (BOOL) hasSnippetsBlog;
+ (BOOL) hasMicropubBlog;
+ (BOOL) prefersExternalBlog;
+ (BOOL) isUsingMicroblog;

+ (BOOL) boolForKey:(NSString *)prefKey;
+ (BOOL) boolForKey:(NSString *)prefKey account:(RFAccount *)account;
+ (void) setBool:(BOOL)value forKey:(NSString *)prefKey;
+ (void) setBool:(BOOL)value forKey:(NSString *)prefKey account:(RFAccount *)account;

+ (NSString *) stringForKey:(NSString *)prefKey;
+ (NSString *) stringForKey:(NSString *)prefKey account:(RFAccount *)account;
+ (void) setString:(NSString *)value forKey:(NSString *)prefKey;
+ (void) setString:(NSString *)value forKey:(NSString *)prefKey account:(RFAccount *)account;

+ (void) removeObjectForKey:(NSString *)prefKey;
+ (void) removeObjectForKey:(NSString *)prefKey account:(RFAccount *)account;

@end

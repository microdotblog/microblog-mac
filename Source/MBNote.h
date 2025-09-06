//
//  MBNote.h
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBNote : NSObject <NSCopying>

@property (strong) NSNumber* noteID;
@property (strong) NSNumber* notebookID;
@property (copy) NSString* text;
@property (copy) NSString* sharedURL;
@property (assign) BOOL isEncrypted;
@property (assign) BOOL isShared;
@property (assign) BOOL isSharing;
@property (assign) BOOL isUnsharing;
@property (copy) NSString* attachedBookISBN;
@property (copy) NSString* attachedBookTitle;
@property (strong) NSDate* createdAt;
@property (strong) NSDate* updatedAt;

+ (BOOL) hasSecretKey;
+ (NSString *) cleanKey:(NSString *)key;

+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)key;
+ (NSString *) decryptText:(NSString *)text withKey:(NSString *)key;

+ (BOOL) isProbablyEncrypted:(NSString *)text;

@end

NS_ASSUME_NONNULL_END

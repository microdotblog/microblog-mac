//
//  RFAccount.h
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface RFAccount : NSObject

@property (strong) NSString* username;

- (NSString *) profileImageURL;
- (NSImage *) cachedProfileImage;
- (void) saveProfileImage:(NSImage *)image;
+ (void) clearCache;

@end

//
//  MBNotebook.h
//  Micro.blog
//
//  Created by Manton Reece on 2/11/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBNotebook : NSObject

@property (strong) NSNumber* notebookID;
@property (strong) NSString* name;
@property (strong) NSColor* lightColor;
@property (strong) NSColor* darkColor;

@end

NS_ASSUME_NONNULL_END

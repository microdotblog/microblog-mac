//
//  MBHighlight.h
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBHighlight : NSObject

@property (strong) NSNumber* highlightID;
@property (strong) NSString* selectionText;
@property (strong) NSString* title;
@property (strong) NSString* url;

@end

NS_ASSUME_NONNULL_END

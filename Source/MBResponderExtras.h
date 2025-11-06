//
//  MBResponderExtras.h
//  Micro.blog
//
//  Created by Manton Reece on 11/4/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MBResponderExtras

- (void) openRow:(id)sender;
- (void) moveLeft;
- (void) moveRight;

@end

NS_ASSUME_NONNULL_END

//
//  RFPostWindowController.h
//  Snippets
//
//  Created by Manton Reece on 8/12/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class RFPostController;

@interface RFPostWindowController : NSWindowController

@property (strong, nonatomic) RFPostController* postController;

- (instancetype) initWithPostController:(RFPostController *)postController;

@end

NS_ASSUME_NONNULL_END
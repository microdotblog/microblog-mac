//
//  RFGoToUserController.h
//  Micro.blog
//
//  Created by Manton Reece on 11/10/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFGoToUserController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextField* usernameField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@end

NS_ASSUME_NONNULL_END

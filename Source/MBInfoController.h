//
//  MBInfoController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/9/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBInfoController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextField* urlField;
@property (strong, nonatomic) IBOutlet NSTextField* textField;
@property (strong, nonatomic) IBOutlet NSButton* textCopyButton;

@property (strong, nonatomic) NSString* url;
@property (strong, nonatomic) NSString* text;

- (id) init;
- (void) setupWithURL:(NSString *)url text:(NSString *)text;

@end

NS_ASSUME_NONNULL_END

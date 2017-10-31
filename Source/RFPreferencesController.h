//
//  RFPreferencesController.h
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFWordpressController;

@interface RFPreferencesController : NSWindowController <NSTextFieldDelegate>

@property (strong, nonatomic) IBOutlet NSTextField* messageField;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* messageTopConstraint;
@property (strong, nonatomic) IBOutlet NSButton* publishHostedBlog;
@property (strong, nonatomic) IBOutlet NSButton* publishWordPressBlog;
@property (strong, nonatomic) IBOutlet NSButton* returnButton;
@property (strong, nonatomic) IBOutlet NSTextField* websiteField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSPopUpButton* postFormatPopup;
@property (strong, nonatomic) IBOutlet NSPopUpButton* categoryPopup;
@property (strong, nonatomic) IBOutlet NSPopUpButton* textSizePopup;

@property (strong, nonatomic) RFWordpressController* wordpressController;
@property (assign, nonatomic) BOOL hasLoadedCategories;

- (void) showMessage:(NSString *)message;

@end

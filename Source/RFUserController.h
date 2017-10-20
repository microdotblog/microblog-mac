//
//  RFUserController.h
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RFUserController : NSViewController

@property (strong, nonatomic) IBOutlet NSTextField* headerField;
@property (strong, nonatomic) IBOutlet NSTextField* bioField;
@property (strong, nonatomic) IBOutlet NSBox* bioDivider;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* bioSpacingConstraint;
@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSButton* followButton;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSButton* followingUsersButton;

@property (strong, nonatomic) NSString* username;

- (instancetype) initWithUsername:(NSString *)username;

@end

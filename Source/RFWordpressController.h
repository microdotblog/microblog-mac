//
//  RFWordpressController.h
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFWordpressController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextField* usernameField;
@property (strong, nonatomic) IBOutlet NSTextField* passwordField;
@property (strong, nonatomic) IBOutlet NSTextField* websiteField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSString* websiteURL;
@property (strong, nonatomic) NSString* rsdURL;

- (instancetype) initWithWebsite:(NSString *)websiteURL rsdURL:(NSString *)rsdURL;

@end

//
//  RFOptionsController.h
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	kOptionsPopoverDefault = 0,
	kOptionsPopoverWithUnfavorite = 1,
	kOptionsPopoverWithDelete = 2
} RFOptionsPopoverType;

@interface RFOptionsController : NSViewController

@property (strong, nonatomic) IBOutlet NSButton* replyButton;
@property (strong, nonatomic) IBOutlet NSButton* favoriteButton;
@property (strong, nonatomic) IBOutlet NSButton* conversationButton;

@property (strong, nonatomic) NSString* postID;
@property (strong, nonatomic) NSString* username;
@property (assign, nonatomic) RFOptionsPopoverType popoverType;

- (instancetype) initWithPostID:(NSString *)postID username:(NSString *)username popoverType:(RFOptionsPopoverType)popoverType;

@end

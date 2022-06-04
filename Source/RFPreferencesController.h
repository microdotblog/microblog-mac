//
//  RFPreferencesController.h
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFAccount;
@class RFWordpressController;

@interface RFPreferencesController : NSWindowController <NSTextFieldDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSTextField* messageField;
@property (strong, nonatomic) IBOutlet NSBox* messageHeader;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* messageTopConstraint;
@property (strong, nonatomic) IBOutlet NSButton* publishHostedBlog;
@property (strong, nonatomic) IBOutlet NSButton* publishWordPressBlog;
@property (strong, nonatomic) IBOutlet NSButton* websiteReturnButton;
@property (strong, nonatomic) IBOutlet NSTextField* websiteField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSTextField *postFormatField;
@property (strong, nonatomic) IBOutlet NSPopUpButton* postFormatPopup;
@property (strong, nonatomic) IBOutlet NSTextField *categoryField;
@property (strong, nonatomic) IBOutlet NSPopUpButton* categoryPopup;
@property (strong, nonatomic) IBOutlet NSPopUpButton* textSizePopup;
@property (strong, nonatomic) IBOutlet NSCollectionView* accountsCollectionView;
@property (strong, nonatomic) IBOutlet NSBox* wordPressSeparatorLine;
@property (strong, nonatomic) IBOutlet NSTextField* dayOneJournalNameField;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* dayOneJournalTopConstraint;

@property (strong, nonatomic) RFWordpressController* wordpressController;
@property (assign, nonatomic) BOOL hasShownWindow;
@property (assign, nonatomic) BOOL hasLoadedCategories;
@property (assign, nonatomic) BOOL isShowingWordPressMenus;
@property (strong, nonatomic) NSArray* accounts; // RFAccount
@property (strong, nonatomic) RFAccount* selectedAccount;

- (void) showMessage:(NSString *)message;

@end

//
//  RFTimelineController.h
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class RFPostController;
@class RFAllPostsController;
@class RFRoundedImageView;
@class RFConversationController;
@class RFDiscoverController;
@class RFStack;
@class RFAccount;
@class RFGoToUserController;
@class MBNotesController;

typedef NSInteger RFSelectedTimelineType;

@interface RFTimelineController : NSWindowController <NSSplitViewDelegate, NSTableViewDelegate, NSTableViewDataSource, WebFrameLoadDelegate, WebPolicyDelegate, WebResourceLoadDelegate, WebUIDelegate, NSUserNotificationCenterDelegate, NSSharingServicePickerDelegate, NSToolbarDelegate>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSSplitView* splitView;
@property (strong, nonatomic) IBOutlet NSView* containerView;
@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSTextField* fullNameField;
@property (strong, nonatomic) IBOutlet NSTextField* usernameField;
@property (strong, nonatomic) IBOutlet RFRoundedImageView* profileImageView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* messageTopConstraint;
@property (strong, nonatomic) IBOutlet NSTextField* messageField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* messageSpinner;
@property (strong, nonatomic) IBOutlet NSBox* profileBox;
@property (strong, nonatomic) IBOutlet NSImageView* switchAccountView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* timelineLeftConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* timelineRightConstraint;
@property (strong, nonatomic) IBOutlet NSView* statusBubble;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* statusProgressSpinner;

@property (strong, nonatomic) NSSplitViewController* splitController;
@property (strong, nonatomic) NSViewController* sidebarController;
@property (strong, nonatomic) NSViewController* contentController;
@property (strong, nonatomic) RFAccount* selectedAccount;
@property (strong, nonatomic) RFPostController* postController;
@property (strong, nonatomic) NSViewController* rootController;
@property (strong, nonatomic) RFDiscoverController* discoverController;
@property (assign, nonatomic) RFSelectedTimelineType selectedTimeline;
@property (strong, nonatomic) RFStack* navigationStack;
@property (strong, nonatomic) NSLayoutConstraint* navigationLeftConstraint;
@property (strong, nonatomic) NSLayoutConstraint* navigationRightConstraint;
@property (strong, nonatomic) NSLayoutConstraint* navigationPinnedConstraint;
@property (strong, nonatomic) NSLayoutConstraint* overlayLeftConstraint;
@property (strong, nonatomic) NSLayoutConstraint* overlayRightConstraint;
@property (strong, nonatomic) NSTimer* checkTimer;
@property (strong, nonatomic) NSNumber* checkSeconds;
@property (strong, nonatomic) RFGoToUserController* goToUserController;
@property (strong, nonatomic) NSMutableArray* sidebarItems; // RFSelectedTimelineType
@property (strong, nonatomic) NSMutableArray* booksWindowControllers; // MBBooksWindowController
@property (strong, nonatomic) MBNotesController* notesController;
@property (strong, nonatomic) NSString* selectedPostID;
@property (strong, nonatomic) NSMutableSet* cachedUsernames;

// NOTES:
// have stack of NSViewControllers (use RFXMLElementStack, rename it)
// rename RFTimelineController to RFMainController
// make an RFTimelineController that is just a web view

- (IBAction) performClose:(id)sender;
- (IBAction) showFavorites:(id)sender;

- (void) showConversationWithPostID:(NSString *)postID;
- (void) showProfileWithUsername:(NSString *)username;
- (void) setSelected:(BOOL)isSelected withPostID:(NSString *)postID;
- (NSString *) usernameOfPostID:(NSString *)postID;

- (BOOL) isSelectedFavorites;

@end

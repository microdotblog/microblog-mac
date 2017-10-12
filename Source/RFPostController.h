//
//  RFPostController.h
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFHighlightingTextStorage;

@interface RFPostController : NSViewController <NSTextViewDelegate, NSTextStorageDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextView* textView;
@property (strong, nonatomic) IBOutlet NSButton* postButton;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSTextField* remainingField;
@property (strong, nonatomic) IBOutlet NSTextField* hostnameField;
@property (strong, nonatomic) IBOutlet NSButton* photoButton;
@property (strong, nonatomic) IBOutlet NSCollectionView* photosCollectionView;

@property (assign, nonatomic) BOOL isReply;
@property (strong, nonatomic) NSString* replyPostID;
@property (strong, nonatomic) NSString* replyUsername;
@property (strong, nonatomic) NSArray* attachedPhotos; // RFPhoto
@property (strong, nonatomic) NSArray* queuedPhotos; // RFPhoto
@property (strong, nonatomic) RFHighlightingTextStorage* textStorage;

- (id) initWithPostID:(NSString *)postID username:(NSString *)username;

@end

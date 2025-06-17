//
//  RFPhotoAltController.h
//  Snippets
//
//  Created by Manton Reece on 1/12/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class RFPhoto;

@interface RFPhotoAltController : NSWindowController <NSTextViewDelegate>

@property (strong, nonatomic) IBOutlet NSImageView* imageView;
@property (strong, nonatomic) IBOutlet NSTextView* descriptionField;
@property (strong, nonatomic) IBOutlet NSButton* okButton;
@property (strong, nonatomic) IBOutlet NSButton* cancelButton;
@property (strong, nonatomic) IBOutlet NSButton* removeButton;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSTextField* progressStatusField;

@property (strong, nonatomic) RFPhoto* photo;
@property (strong, nonatomic) NSIndexPath* indexPath;
@property (strong, nonatomic, nullable) NSTimer* altTextTimer;
@property (assign) BOOL isCancelled;

- (id) initWithPhoto:(RFPhoto *)photo atIndex:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

//
//  MBMovieCell.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBMovie;
@class RFRoundedImageView;

@interface MBMovieCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSImageView* posterImageView;
@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextField* subtitleField;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* leftConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* disclosureInsetConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* statusLeftConstraint;
@property (strong, nonatomic) IBOutlet NSButton* disclosureTriangle;
@property (strong, nonatomic) IBOutlet NSButton* postButton;
@property (strong, nonatomic) IBOutlet RFRoundedImageView* profileImageView;

@property (strong, nonatomic) MBMovie* movie;
@property (assign, nonatomic) BOOL needsInset;

- (void) setupWithMovie:(MBMovie *)movie;
- (void) setDisclosureOpen:(BOOL)isOpen;

@end

NS_ASSUME_NONNULL_END

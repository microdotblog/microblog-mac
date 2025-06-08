//
//  RFPhotoCell.h
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MBCollection;

@interface RFPhotoCell : NSCollectionViewItem

@property (strong, nonatomic) IBOutlet NSImageView* thumbnailImageView;
@property (strong, nonatomic) IBOutlet NSView* selectionOverlayView;
@property (strong, nonatomic) IBOutlet NSImageView* iconView;
@property (strong, nonatomic) IBOutlet NSMenuItem* removeFromCollectionItem;
@property (strong, nonatomic) IBOutlet NSMenuItem* browserMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem* htmlWithoutPlayerItem;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSString* url;
@property (strong, nonatomic) NSString* poster_url;
@property (strong, nonatomic) NSString* alt;
@property (assign, nonatomic) BOOL isAI;
@property (copy, nonatomic) NSMenuItem* copiedRemoveItem;

- (void) setupForURL;
- (void) setupForCollection:(MBCollection *)collection;
- (void) disableMenu;

@end

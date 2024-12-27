//
//  RFPhotoZoomController.h
//  Snippets
//
//  Created by Manton Reece on 1/10/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPhotoZoomController : NSWindowController <NSWindowDelegate>

@property (strong, nonatomic) IBOutlet NSImageView* imageView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* spinner;
@property (strong, nonatomic) IBOutlet NSButton* htmlCopyButton;

@property (strong, nonatomic) NSString* photoURL;
@property (strong, nonatomic) NSString* photoAlt;
@property (assign, nonatomic) BOOL isAllowCopy;

- (id) initWithURL:(NSString *)photoURL altText:(NSString *)photoAlt allowCopy:(BOOL)allowCopy;

@end

NS_ASSUME_NONNULL_END

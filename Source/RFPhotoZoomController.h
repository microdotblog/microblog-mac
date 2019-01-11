//
//  RFPhotoZoomController.h
//  Snippets
//
//  Created by Manton Reece on 1/10/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPhotoZoomController : NSWindowController

@property (strong, nonatomic) IBOutlet NSImageView* imageView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* spinner;

@property (strong, nonatomic) NSString* photoURL;

- (id) initWithURL:(NSString *)photoURL;

@end

NS_ASSUME_NONNULL_END

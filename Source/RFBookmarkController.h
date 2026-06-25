//
//  RFBookmarkController.h
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFBookmarkController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextField* urlField;
@property (strong, nonatomic) IBOutlet NSTextField* statusField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSImageView* warningIconView;

@property (strong, nonatomic) NSString* initialURL;

- (instancetype) initWithURL:(NSString *)url;
- (void) showBookmarkWindow;
- (void) showBookmarkWindowWithURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END

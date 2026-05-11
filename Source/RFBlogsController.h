//
//  RFBlogsController.h
//  Snippets
//
//  Created by Manton Reece on 3/21/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFBlogsController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSArray* destinations; // NSDictionary (uid, name)
@property (strong, nonatomic) NSTimer* progressTimer;

+ (NSArray *) cachedDestinations;
+ (void) saveCachedDestinationsFrom:(NSArray *)destinations;
+ (void) clearCachedDestinations;
+ (void) fetchDestinationsInBackgroundWithCompletion:(void (^)(NSArray* destinations))completion;
+ (NSMenu *) blogsMenuWithTarget:(id)target action:(SEL)action;
+ (void) selectDestinationMenuItem:(NSMenuItem *)menuItem;
+ (BOOL) hasMultipleCachedDestinations;

@end

@interface RFHostnameButton : NSButton

@property (assign, nonatomic) BOOL showsChevron;

@end

@interface RFHostnameField : NSTextField

@property (assign, nonatomic) BOOL showsChevron;
@property (copy, nonatomic) void (^mouseDownHandler)(RFHostnameField* field, NSEvent* event);

- (NSRect) hostnameRect;

@end

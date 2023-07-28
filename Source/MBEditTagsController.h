//
//  MBEditTagsController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/27/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MBBookmark;

NS_ASSUME_NONNULL_BEGIN

@interface MBEditTagsController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTokenField* tagsField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSString* bookmarkID;
@property (strong, nonatomic) MBBookmark* bookmark;

- (id) initWithBookmarkID:(NSString *)bookmarkID;

@end

NS_ASSUME_NONNULL_END

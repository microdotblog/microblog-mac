//
//  AppDelegate.h
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFTimelineController;
@class RFWelcomeController;
@class RFPreferencesController;
@class RFInstagramController;
@class MBGlassController;
@class MBBlogImportController;
@class RFExportController;
@class RFBookmarkController;
@class MBPreviewController;
@class MBEditTagsController;
@class MBAllTagsController;
@class MBLogsController;
@class MBInfoController;
@class MBCollectionsController;

@interface RFAppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) RFTimelineController* timelineController;
@property (strong, nonatomic) RFWelcomeController* welcomeController;
@property (strong, nonatomic) RFPreferencesController* prefsController;
@property (strong, nonatomic) RFInstagramController* instagramController;
@property (strong, nonatomic) MBGlassController* glassController;
@property (strong, nonatomic) MBBlogImportController* blogImportController;
@property (strong, nonatomic) RFExportController* exportController;
@property (strong, nonatomic) RFBookmarkController* bookmarkController;
@property (strong, nonatomic) MBPreviewController* previewController;
@property (strong, nonatomic) MBEditTagsController* editTagsController;
@property (strong, nonatomic) MBAllTagsController* allTagsController;
@property (strong, nonatomic) MBLogsController* logsController;
@property (strong, nonatomic) MBInfoController* infoController;
@property (strong, nonatomic) MBCollectionsController* collectionsController;
@property (strong, nonatomic) NSMutableArray* postWindows; // RFPostWindowController
@property (strong, nonatomic) NSMutableArray* photoWindows; // RFPhotoZoomController

@end


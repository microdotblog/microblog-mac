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
@class RFExportController;
@class RFBookmarkController;

@interface RFAppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) RFTimelineController* timelineController;
@property (strong, nonatomic) RFWelcomeController* welcomeController;
@property (strong, nonatomic) RFPreferencesController* prefsController;
@property (strong, nonatomic) RFInstagramController* instagramController;
@property (strong, nonatomic) RFExportController* exportController;
@property (strong, nonatomic) RFBookmarkController* bookmarkController;
@property (strong, nonatomic) NSMutableArray* postWindows; // RFPostWindowController

@end


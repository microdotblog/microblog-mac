//
//  RFConstants.h
//  Snippets
//
//  Created by Manton Reece on 8/25/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

static NSString* const kLoadTimelineNotification = @"RFLoadTimeline";
static NSString* const kOpenPostingNotification = @"RFOpenPosting";
static NSString* const kClosePostingNotification = @"RFClosePosting";

static NSString* const kLatestDraftTitlePrefKey = @"LatestDraftTitle";
static NSString* const kLatestDraftTextPrefKey = @"LatestDraftText";

#define kOpenMicroblogURLNotification @"RFOpenMicroblogURL"
#define kOpenMicroblogURLKey @"url"

#define kShowConversationNotification @"RFShowConversationNotification"
#define kShowConversationPostIDKey @"post_id"

#define kAttachFilesNotification @"RFAttachFilesNotification"
#define kAttachFilesPathsKey @"paths"

#define kPopNavigationNotification @"RFPopNavigationNotification"

#define kShowUserFollowingNotification @"RFShowUserFollowingNotification"
#define kShowUserFollowingUsernameKey @"username"

#define kShowUserProfileNotification @"RFShowUserProfileNotification"
#define kShowUserProfileUsernameKey @"username"

#define kShowReplyPostNotification @"RFShowReplyPostNotification"
#define kShowReplyPostIDKey @"post_id"
#define kShowReplyPostUsernameKey @"username"

#define kShowSigninNotification @"RFShowSigninNotification"

#define kPostWasFavoritedNotification @"RFPostWasFavoritedNotification"
#define kPostWasUnfavoritedNotification @"RFPostWasUnfavoritedNotification"
#define kPostWasDeletedNotification @"RFPostWasDeletedNotification"
#define kPostWasUnselectedNotification @"RFPostWasUnselectedNotification"
#define kPostNotificationPostIDKey @"post_id"

#define kSharePostNotification @"RFSharePostNotification"
#define kSharePostIDKey @"post_id"

#define kOpenURLNotification @"RFOpenURLNotification"
#define kOpenURLKey @"url"

static NSString* const kResetDetailNotification = @"RFResetDetail";
static NSString* const kResetDetailControllerKey = @"controller";

static NSString* const kShortcutActionNewPost = @"com.riverfold.snippets.shortcut.post";

#define APPSTORE 1

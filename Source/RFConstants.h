//
//  RFConstants.h
//  Snippets
//
//  Created by Manton Reece on 8/25/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

static NSString* const kLoadTimelineNotification = @"RFLoadTimeline";
static NSString* const kOpenPostingNotification = @"RFOpenPosting";
static NSString* const kOpenPostingPostKey = @"post";
static NSString* const kClosePostingNotification = @"RFClosePosting";
static NSString* const kDraftDidUpdateNotification = @"MBDraftDidUpdate";
static NSString* const kReplyDidUpdateNotification = @"MBReplyDidUpdate";
static NSString* const kRefreshTimelineNotification = @"RFRefreshTimeline";
static NSString* const kCheckTimelineNotification = @"RFCheckTimeline";
static NSString* const kUpdatedBlogNotification = @"RFUpdatedBlog";
static NSString* const kRemoveAttachedPhotoNotification = @"RFRemoveAttachedPhoto";
static NSString* const kRemoveAttachedPhotoIndexPath = @"index_path";

static NSString* const kPostWindowDidCloseNotification = @"RFPostWindowDidClose";
static NSString* const kPhotoWindowDidCloseNotification = @"MBPhotoWindowDidClose";

static NSString* const kSwitchAccountNotification = @"RFSwitchAccount";
static NSString* const kSwitchAccountUsernameKey = @"username";

static NSString* const kRemoveAccountNotification = @"RFRemoveAccount";
static NSString* const kRefreshAccountsNotification = @"RFRefreshAccounts";

static NSString* const kPostStartProgressNotification = @"RFPostStartProgress";
static NSString* const kPostStopProgressNotification = @"RFPostStopProgress";

static NSString* const kFoundUserAutoCompleteNotification = @"RFFoundUserAutoCompleteNotification";
static NSString* const kFoundUserAutoCompleteInfoKey = @"RFFoundUserAutoCompleteInfokey";

static NSString* const kOpenBookshelfNotification = @"MBOpenBookshelfNotification";
static NSString* const kOpenBookshelfKey = @"bookshelf";

static NSString* const kTextSizePrefKey = @"TextSize";
static NSInteger const kTextSizeTiny = 12;
static NSInteger const kTextSizeSmall = 13;
static NSInteger const kTextSizeMedium = 15;
static NSInteger const kTextSizeLarge = 17;
static NSInteger const kTextSizeHuge = 19;

static NSInteger const kMaxCharsDefault = 300;
static NSInteger const kMaxCharsBlockquote = 600;

static NSString* const kSaveNotesToFolderPrefKey = @"SaveNotesToFolder";
static NSString* const kSaveKeyToCloudPrefKey = @"SaveKeyToCloud";

#define kOpenMicroblogURLNotification @"RFOpenMicroblogURL"
#define kOpenMicroblogURLKey @"url" // NSURL

#define kOpenPhotoURLNotification @"RFOpenPhotoURL"
#define kOpenPhotoURLKey @"url" // NSURL
#define kOpenPhotoAllowCopyKey @"allow_copy" // NSNumber

#define kShowConversationNotification @"RFShowConversationNotification"
#define kShowConversationPostIDKey @"post_id"

#define kSharePostNotification @"RFSharePostNotification"
#define kSharePostIDKey @"post_id"

#define kAttachFilesNotification @"RFAttachFilesNotification"
#define kAttachFilesPathsKey @"paths"

#define kUploadFilesNotification @"RFUploadFilesNotification"
#define kUploadFilesPathsKey @"paths"

#define kPopNavigationNotification @"RFPopNavigationNotification"

#define kShowUserFollowingNotification @"RFShowUserFollowingNotification"
#define kShowUserFollowingUsernameKey @"username"

#define kShowUserProfileNotification @"RFShowUserProfileNotification"
#define kShowUserProfileUsernameKey @"username"

#define kShowDiscoverTopicNotification @"RFShowDiscoverTopicNotification"
#define kShowDiscoverTopicNameKey @"name"

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

static NSString* const kSignOutNotification = @"RFSignOut";

static NSString* const kResetDetailNotification = @"RFResetDetail";
static NSString* const kResetDetailControllerKey = @"controller";

static NSString* const kShortcutActionNewPost = @"com.riverfold.snippets.shortcut.post";

static NSString* const kDarkModeAppearanceDidChangeNotification = @"DarkModeAppearanceDidChange";

static NSString* const kEditorWindowTextDidChangeNotification = @"EditorWindowTextDidChange";
static NSString* const kEditorWindowTextTitleKey = @"title";
static NSString* const kEditorWindowTextMarkdownKey = @"markdown";

static NSString* const kAddBookNotification = @"AddBookNotification";
static NSString* const kAddBookKey = @"book";
static NSString* const kAddBookBookshelfKey = @"bookshelf";

static NSString* const kBookWasAddedNotification = @"BookWasAddedNotification";
static NSString* const kBookWasAddedBookshelfKey = @"bookshelf";

static NSString* const kBookWasRemovedNotification = @"BookWasRemovedNotification";
static NSString* const kBookWasRemovedBookshelfKey = @"bookshelf";

static NSString* const kBookWasAssignedNotification = @"BookWasAssignedNotification";
static NSString* const kBookWasAssignedBookshelfKey = @"bookshelf";

static NSString* const kSelectPhotoCellNotification = @"SelectPhotoCellNotification";
static NSString* const kSelectPhotoCellKey = @"cell"; // RFPhotoCell

static NSString* const kTimelineDidStartLoading = @"TimelineDidStartLoading";
static NSString* const kTimelineDidStopLoading = @"TimelineDidStopLoading";
static NSString* const kTimelineSidebarRowKey = @"row";

static NSString* const kShowHighlightsNotification = @"MBShowHighlightsNotification";

static NSString* const kTagsDidUpdateNotification = @"MBTagsDidUpdateNotification";
static NSString* const kTagsDidUpdateIDKey = @"id";
static NSString* const kTagsDidUpdateTagsKey = @"tags";

static NSString* const kShowTagsNotification = @"MBShowTagsNotification";

static NSString* const kSelectTagNotification = @"MBSelectTagNotification";
static NSString* const kSelectTagNameKey = @"name";

static NSString* const kNewNoteNotification = @"MBNewNoteNotification";
static NSString* const kNotesKeyUpdatedNotification = @"MBNotesKeyUpdatedNotification";

static NSString* const kShowLogsNotification = @"MBShowLogsNotification";
static NSString* const kDeleteSelectedPhotoNotification = @"MBDeleteSelectedPhotoNotification";

#define APPSTORE 1

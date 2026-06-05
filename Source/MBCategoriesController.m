//
//  MBCategoriesController.m
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBCategoriesController.h"

#import "MBCategory.h"
#import "MBCategoryCell.h"
#import "MBCategoriesTableView.h"
#import "MBSplitView.h"
#import "RFPostCell.h"
#import "RFPostTableView.h"
#import "RFPost.h"
#import "RFBlogsController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"

static NSString* const kCategoryCellIdentifier = @"CategoryCell";
static NSInteger const kCategoriesPostsLimit = 200;
static CGFloat const kCategoriesInitialRatio = 0.30;
static CGFloat const kCategoriesMinimumPaneHeight = 120.0;

@interface MBCategoriesController ()

@property (strong, nonatomic) NSScrollView* categoriesScrollView;
@property (strong, nonatomic) NSScrollView* postsScrollView;
@property (strong, nonatomic) NSTextField* categoryEditField;
@property (strong, nonatomic) MBCategory* editingCategory;
@property (assign, nonatomic) NSInteger categoriesRequestID;
@property (assign, nonatomic) NSInteger postsRequestID;
@property (assign, nonatomic) NSInteger editingCategoryRow;
@property (assign, nonatomic) BOOL isObservingWindowNotifications;
@property (assign, nonatomic) BOOL didSetInitialSplitPosition;

@end

@implementation MBCategoriesController

- (instancetype) init
{
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		self.categories = @[];
		self.currentPosts = @[];
		self.editingCategoryRow = -1;
	}

	return self;
}

- (void) loadView
{
	NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 520)];
	view.translatesAutoresizingMaskIntoConstraints = NO;
	self.view = view;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self setupViews];
	[self setupBlogName];
	[self setupTables];
	[self setupMenus];
	[self setupNotifications];

	[self fetchCategories];
}

- (void) viewDidAppear
{
	[super viewDidAppear];

	if (!self.isObservingWindowNotifications && self.view.window != nil) {
		self.isObservingWindowNotifications = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.view.window];
	}

	[self refreshDestinationsCache];
	[self scheduleInitialSplitPosition];
}

- (void) viewDidDisappear
{
	[super viewDidDisappear];

	if (self.isObservingWindowNotifications) {
		self.isObservingWindowNotifications = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
}

- (void) dealloc
{
	if (self.isObservingWindowNotifications) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
}

- (void) setupViews
{
	NSView* header_view = [[NSView alloc] initWithFrame:NSZeroRect];
	header_view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:header_view];

	RFHostnameButton* blog_name_button = [[RFHostnameButton alloc] initWithFrame:NSZeroRect];
	blog_name_button.translatesAutoresizingMaskIntoConstraints = NO;
	blog_name_button.hidden = YES;
	blog_name_button.target = self;
	blog_name_button.action = @selector(blogNameClicked:);
	blog_name_button.bezelStyle = NSBezelStyleRounded;
	blog_name_button.bordered = NO;
	blog_name_button.alignment = NSTextAlignmentLeft;
	blog_name_button.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	self.blogNameButton = blog_name_button;
	[header_view addSubview:blog_name_button];

	NSBox* header_separator = [[NSBox alloc] initWithFrame:NSZeroRect];
	header_separator.translatesAutoresizingMaskIntoConstraints = NO;
	header_separator.boxType = NSBoxSeparator;
	[header_view addSubview:header_separator];

	MBSplitView* split_view = [[MBSplitView alloc] initWithFrame:NSZeroRect];
	split_view.translatesAutoresizingMaskIntoConstraints = NO;
	split_view.vertical = NO;
	split_view.dividerStyle = NSSplitViewDividerStyleThin;
	split_view.delegate = self;
	self.splitView = split_view;
	[self.view addSubview:split_view];

	NSScrollView* categories_scroll_view = [self scrollView];
	self.categoriesTableView = [[MBCategoriesTableView alloc] initWithFrame:NSZeroRect];
	[self setupTable:self.categoriesTableView rowHeight:34.0];
	categories_scroll_view.documentView = self.categoriesTableView;
	self.categoriesScrollView = categories_scroll_view;

	NSScrollView* posts_scroll_view = [self scrollView];
	self.postsTableView = [[RFPostTableView alloc] initWithFrame:NSZeroRect];
	[self setupTable:self.postsTableView rowHeight:120.0];
	self.postsTableView.usesAlternatingRowBackgroundColors = YES;
	self.postsTableView.usesAutomaticRowHeights = YES;
	posts_scroll_view.documentView = self.postsTableView;
	self.postsScrollView = posts_scroll_view;

	[split_view addSubview:categories_scroll_view];
	[split_view addSubview:posts_scroll_view];

	self.progressSpinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
	self.progressSpinner.translatesAutoresizingMaskIntoConstraints = NO;
	self.progressSpinner.indeterminate = YES;
	self.progressSpinner.displayedWhenStopped = NO;
	self.progressSpinner.bezeled = NO;
	self.progressSpinner.controlSize = NSControlSizeSmall;
	self.progressSpinner.style = NSProgressIndicatorStyleSpinning;
	[self.view addSubview:self.progressSpinner];

	[NSLayoutConstraint activateConstraints:@[
		[header_view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[header_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[header_view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[header_view.heightAnchor constraintEqualToConstant:45],
		[blog_name_button.leadingAnchor constraintEqualToAnchor:header_view.leadingAnchor constant:18],
		[blog_name_button.topAnchor constraintEqualToAnchor:header_view.topAnchor constant:5],
		[blog_name_button.heightAnchor constraintEqualToConstant:32],
		[header_separator.leadingAnchor constraintEqualToAnchor:header_view.leadingAnchor],
		[header_separator.trailingAnchor constraintEqualToAnchor:header_view.trailingAnchor],
		[header_separator.bottomAnchor constraintEqualToAnchor:header_view.bottomAnchor],
		[header_separator.heightAnchor constraintEqualToConstant:1],
		[split_view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[split_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[split_view.topAnchor constraintEqualToAnchor:header_view.bottomAnchor],
		[split_view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[self.progressSpinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
		[self.progressSpinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
	]];
}

- (void) viewDidLayout
{
	[super viewDidLayout];

	[self setInitialSplitPositionIfReady];
}

- (void) scheduleInitialSplitPosition
{
	if (self.didSetInitialSplitPosition) {
		return;
	}

	RFDispatchMainAsync(^{
		[self.view layoutSubtreeIfNeeded];
		[self setInitialSplitPositionIfReady];
	});
}

- (void) setInitialSplitPositionIfReady
{
	if (self.didSetInitialSplitPosition) {
		return;
	}

	CGFloat width = self.splitView.bounds.size.width;
	CGFloat height = self.splitView.bounds.size.height;
	CGFloat divider_thickness = self.splitView.dividerThickness;
	if (width <= 0.0 || height < ((kCategoriesMinimumPaneHeight * 2.0) + divider_thickness)) {
		return;
	}

	self.didSetInitialSplitPosition = YES;
	CGFloat initial_height = round (height * kCategoriesInitialRatio);
	initial_height = MAX (kCategoriesMinimumPaneHeight, initial_height);
	initial_height = MIN (initial_height, height - kCategoriesMinimumPaneHeight - divider_thickness);
	self.categoriesScrollView.frame = NSMakeRect(0.0, 0.0, width, initial_height);
	self.postsScrollView.frame = NSMakeRect(0.0, initial_height + divider_thickness, width, height - initial_height - divider_thickness);
	[self.splitView adjustSubviews];
	[self.splitView setPosition:initial_height ofDividerAtIndex:0];
}

- (BOOL) splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	#pragma unused(splitView)
	#pragma unused(subview)

	return NO;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	#pragma unused(splitView)
	#pragma unused(proposedMinimumPosition)
	#pragma unused(dividerIndex)

	return kCategoriesMinimumPaneHeight;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	#pragma unused(proposedMaximumPosition)
	#pragma unused(dividerIndex)

	return splitView.bounds.size.height - kCategoriesMinimumPaneHeight;
}

- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
	#pragma unused(splitView)

	return (view == self.postsScrollView);
}

- (void) setupBlogName
{
	NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
	if (s) {
		self.blogNameButton.title = s;
	}
	else {
		self.blogNameButton.title = [RFSettings stringForKey:kAccountDefaultSite];
	}

	if ([self.blogNameButton isKindOfClass:[RFHostnameButton class]]) {
		((RFHostnameButton*) self.blogNameButton).showsChevron = [RFBlogsController hasMultipleCachedDestinations];
	}
}

- (NSScrollView *) scrollView
{
	NSScrollView* scroll_view = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	scroll_view.translatesAutoresizingMaskIntoConstraints = YES;
	scroll_view.autohidesScrollers = YES;
	scroll_view.hasVerticalScroller = YES;
	scroll_view.hasHorizontalScroller = NO;
	scroll_view.usesPredominantAxisScrolling = NO;
	scroll_view.horizontalLineScroll = 17;
	scroll_view.verticalLineScroll = 17;
	scroll_view.horizontalPageScroll = 10;
	scroll_view.verticalPageScroll = 10;
	scroll_view.drawsBackground = YES;
	scroll_view.borderType = NSNoBorder;
	return scroll_view;
}

- (void) setupTable:(NSTableView *)tableView rowHeight:(CGFloat)rowHeight
{
	tableView.allowsExpansionToolTips = YES;
	tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
	tableView.allowsColumnReordering = NO;
	tableView.allowsColumnSelection = YES;
	tableView.allowsColumnResizing = NO;
	tableView.allowsMultipleSelection = NO;
	tableView.autosaveTableColumns = NO;
	tableView.headerView = nil;
	tableView.rowHeight = rowHeight;
	tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
	tableView.delegate = self;
	tableView.dataSource = self;
	tableView.target = self;
	tableView.doubleAction = @selector(openRow:);

	if (@available(macOS 11.0, *)) {
		tableView.style = NSTableViewStylePlain;
	}

	NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"Column"];
	column.width = 520;
	column.minWidth = 40;
	column.maxWidth = 1000;
	column.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
	[tableView addTableColumn:column];
}

- (void) setupTables
{
	[self.postsTableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
	self.categoriesTableView.alphaValue = 0.0;
	self.postsTableView.alphaValue = 0.0;
}

- (void) setupMenus
{
	self.categoryContextMenu = [[NSMenu alloc] initWithTitle:@"Categories"];
	NSMenuItem* edit_category_item = [self.categoryContextMenu addItemWithTitle:@"Rename" action:@selector(editSelectedCategory:) keyEquivalent:@""];
	edit_category_item.target = self;
	NSMenuItem* delete_category_item = [self.categoryContextMenu addItemWithTitle:@"Delete" action:@selector(deleteSelectedCategory:) keyEquivalent:@""];
	delete_category_item.target = self;
	self.categoriesTableView.menu = self.categoryContextMenu;

	self.postContextMenu = [[NSMenu alloc] initWithTitle:@"Posts"];
	NSMenuItem* edit_post_item = [self.postContextMenu addItemWithTitle:@"Edit" action:@selector(openSelectedPost:) keyEquivalent:@""];
	edit_post_item.target = self;
	NSMenuItem* delete_post_item = [self.postContextMenu addItemWithTitle:@"Delete" action:@selector(deleteSelectedPost:) keyEquivalent:@""];
	delete_post_item.target = self;
	[self.postContextMenu addItem:[NSMenuItem separatorItem]];
	NSMenuItem* browser_item = [self.postContextMenu addItemWithTitle:[NSString mb_openInBrowserString] action:@selector(openPostInBrowser:) keyEquivalent:@""];
	browser_item.target = self;
	NSMenuItem* copy_item = [self.postContextMenu addItemWithTitle:@"Copy Link" action:@selector(copyPostLink:) keyEquivalent:@""];
	copy_item.target = self;
	self.postsTableView.menu = self.postContextMenu;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
}

- (void) fetchCategories
{
	[self cancelCategoryRename];

	self.categoriesRequestID++;
	NSInteger request_id = self.categoriesRequestID;

	self.categories = @[];
	self.selectedCategory = nil;
	self.currentPosts = @[];
	[self.categoriesTableView reloadData];
	[self.postsTableView reloadData];
	[self.progressSpinner startAnimation:nil];
	self.blogNameButton.hidden = YES;
	self.categoriesTableView.animator.alphaValue = 0.0;
	self.postsTableView.animator.alphaValue = 0.0;

	NSString* destination_uid = [self currentDestinationUID];
	NSDictionary* args = @{
		@"q": @"category",
		@"mp-destination": destination_uid
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* new_categories = [MBCategory categoriesFromResponse:response.parsedResponse];

			RFDispatchMainAsync (^{
				if (request_id != self.categoriesRequestID) {
					return;
				}

				self.categories = new_categories;
				[self.categoriesTableView reloadData];
				self.categoriesTableView.animator.alphaValue = 1.0;
				[self setupBlogName];
				self.blogNameButton.hidden = NO;

				if (new_categories.count > 0) {
					NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:0];
					[self.categoriesTableView selectRowIndexes:index_set byExtendingSelection:NO];
					[self fetchPosts];
				}
				else {
					[self.progressSpinner stopAnimation:nil];
					[self stopLoadingSidebarRow];
				}
			});
		}
		else {
			RFDispatchMainAsync (^{
				if (request_id != self.categoriesRequestID) {
					return;
				}

				[self.progressSpinner stopAnimation:nil];
				self.blogNameButton.hidden = NO;
				[self stopLoadingSidebarRow];
			});
		}
	}];
}

- (void) fetchPosts
{
	NSInteger row = self.categoriesTableView.selectedRow;
	if (row < 0 || row >= (NSInteger)self.categories.count) {
		self.selectedCategory = nil;
		self.currentPosts = @[];
		[self.postsTableView reloadData];
		return;
	}

	MBCategory* category = [self.categories objectAtIndex:row];
	self.selectedCategory = category;
	self.postsRequestID++;
	NSInteger request_id = self.postsRequestID;

	self.currentPosts = @[];
	[self.postsTableView reloadData];
	self.postsTableView.animator.alphaValue = 0.0;
	[self.progressSpinner startAnimation:nil];

	NSDictionary* args = [self postQueryArgumentsForCategory:category];
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* props = [item objectForKey:@"properties"];
				RFPost* post = [[RFPost alloc] initFromProperties:props];
				post.channel = @"default";
				if ([self post:post isInCategory:category]) {
					[new_posts addObject:post];
				}
			}

			RFDispatchMainAsync (^{
				if (request_id != self.postsRequestID) {
					return;
				}

				self.currentPosts = new_posts;
				[self.postsTableView reloadData];
				[self.progressSpinner stopAnimation:nil];
				self.postsTableView.animator.alphaValue = 1.0;
				[self stopLoadingSidebarRow];
			});
		}
		else {
			RFDispatchMainAsync (^{
				if (request_id != self.postsRequestID) {
					return;
				}

				[self.progressSpinner stopAnimation:nil];
				self.blogNameButton.hidden = NO;
				[self stopLoadingSidebarRow];
			});
		}
	}];
}

- (NSDictionary *) postQueryArgumentsForCategory:(MBCategory *)category
{
	#pragma unused(category)

	return @{
		@"q": @"source",
		@"mp-destination": [self currentDestinationUID],
		@"mp-channel": @"default",
		@"limit": @(kCategoriesPostsLimit)
	};
}

- (BOOL) post:(RFPost *)post isInCategory:(MBCategory *)category
{
	for (NSString* name in post.categories) {
		if ([name isEqualToString:category.name]) {
			return YES;
		}
	}

	return NO;
}

- (NSString *) currentDestinationUID
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	return destination_uid;
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

#pragma mark -

- (IBAction) blogNameClicked:(id)sender
{
	[self showBlogsMenu];
}

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self refreshDestinationsCache];
}

- (void) refreshDestinationsCache
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	[RFBlogsController fetchDestinationsInBackgroundWithCompletion:^(NSArray* destinations) {
		#pragma unused(destinations)
		[self setupBlogName];
	}];
}

- (void) showBlogsMenu
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	NSMenu* menu = [RFBlogsController blogsMenuWithTarget:[RFBlogsController class] action:@selector(selectDestinationMenuItem:)];
	if (menu.numberOfItems == 0) {
		return;
	}

	NSPoint menu_point = NSMakePoint(0.0, NSMinY(self.blogNameButton.bounds));
	[menu popUpMenuPositioningItem:nil atLocation:menu_point inView:self.blogNameButton];
}

- (IBAction) openRow:(id)sender
{
	if (sender == self.categoriesTableView || self.view.window.firstResponder == self.categoriesTableView) {
		[self editSelectedCategory:sender];
	}
	else {
		[self openSelectedPost:sender];
	}
}

- (IBAction) editSelectedCategory:(id)sender
{
	MBCategory* category = [self selectedCategoryForAction];
	if (category == nil) {
		return;
	}

	NSInteger row = self.categoriesTableView.selectedRow;
	[self startEditingCategory:category row:row];
}

- (void) startEditingCategory:(MBCategory *)category row:(NSInteger)row
{
	if (row < 0) {
		return;
	}

	[self cancelCategoryRename];
	[self.categoriesTableView scrollRowToVisible:row];
	self.editingCategory = category;
	self.editingCategoryRow = row;
	self.categoryEditField = nil;
	[self updateVisibleCategoryRow:row];

	RFDispatchMainAsync(^{
		[self focusCategoryRenameField];
	});
}

- (void) focusCategoryRenameField
{
	NSTextField* field = self.categoryEditField;
	if (field == nil && self.editingCategoryRow >= 0) {
		[self updateVisibleCategoryRow:self.editingCategoryRow];
		MBCategoryCell* cell = [self categoryCellForRow:self.editingCategoryRow makeIfNecessary:NO];
		if (cell != nil) {
			field = cell.editField;
		}
	}

	if (field != nil) {
		self.categoryEditField = field;
		[self.view.window makeFirstResponder:field];
		[field selectText:nil];
	}
}

- (IBAction) commitCategoryRename:(id)sender
{
	#pragma unused(sender)

	NSTextField* field = self.categoryEditField;
	MBCategory* category = self.editingCategory;
	if (field == nil || category == nil) {
		return;
	}

	NSString* new_name = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (new_name.length > 0 && ![new_name isEqualToString:category.name]) {
		[self updateCategory:category withName:new_name];
	}

	[self finishEditingCategory];
}

- (void) cancelCategoryRename
{
	[self finishEditingCategory];
}

- (void) finishEditingCategory
{
	NSInteger row = self.editingCategoryRow;
	NSTextField* field = self.categoryEditField;
	self.categoryEditField = nil;
	self.editingCategory = nil;
	self.editingCategoryRow = -1;

	if (field != nil) {
		[self.view.window makeFirstResponder:self.categoriesTableView];
	}

	[self updateVisibleCategoryRow:row];
}

- (MBCategoryCell *) categoryCellForRow:(NSInteger)row makeIfNecessary:(BOOL)makeIfNecessary
{
	if (row < 0 || row >= (NSInteger)self.categories.count) {
		return nil;
	}

	[self.categoriesTableView layoutSubtreeIfNeeded];
	NSTableRowView* row_view = [self.categoriesTableView rowViewAtRow:row makeIfNecessary:makeIfNecessary];
	if ([row_view isKindOfClass:[MBCategoryCell class]]) {
		return (MBCategoryCell*) row_view;
	}
	else {
		return nil;
	}
}

- (void) updateVisibleCategoryRow:(NSInteger)row
{
	MBCategoryCell* cell = [self categoryCellForRow:row makeIfNecessary:YES];
	if (cell == nil) {
		return;
	}

	MBCategory* category = [self.categories objectAtIndex:row];
	if (row == self.editingCategoryRow && self.editingCategory != nil) {
		[cell setupForEditingWithCategory:category target:self action:@selector(commitCategoryRename:) delegate:self];
		self.categoryEditField = cell.editField;
	}
	else {
		[cell setupWithCategory:category];
	}
}

- (IBAction) deleteSelectedCategory:(id)sender
{
	MBCategory* category = [self selectedCategoryForAction];
	if (category == nil) {
		return;
	}

	NSAlert* sheet = [[NSAlert alloc] init];
	sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", category.name];
	sheet.informativeText = @"This category will be removed from your blog.";
	[sheet addButtonWithTitle:@"Delete"];
	[sheet addButtonWithTitle:@"Cancel"];

	[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSAlertFirstButtonReturn) {
			[self deleteCategory:category];
		}
	}];
}

- (void) updateCategory:(MBCategory *)category withName:(NSString *)name
{
	// TODO: Save category rename to the Micropub endpoint when the POST details are finalized.
	category.name = name;
}

- (void) deleteCategory:(MBCategory *)category
{
	NSDictionary* params = @{
		@"action": @"delete-category",
		@"mp-destination": [self currentDestinationUID],
		@"category": category.name
	};

	[self.progressSpinner startAnimation:nil];
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self.progressSpinner stopAnimation:nil];
			if ([self responseHasError:response]) {
				[self showMicropubError:response title:@"Error Deleting Category"];
			}
			else {
				[self fetchCategories];
			}
		});
	}];
}

- (MBCategory *) selectedCategoryForAction
{
	NSInteger row = self.categoriesTableView.selectedRow;
	if (row >= 0 && row < (NSInteger)self.categories.count) {
		return [self.categories objectAtIndex:row];
	}
	else {
		return nil;
	}
}

- (IBAction) openSelectedPost:(id)sender
{
	RFPost* post = [self selectedPostForAction];
	if (post != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPostingNotification object:self userInfo:@{ kOpenPostingPostKey: post }];
	}
}

- (IBAction) openPostInBrowser:(id)sender
{
	RFPost* post = [self selectedPostForAction];
	if (post.url.length > 0) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:post.url]];
	}
}

- (IBAction) copyPostLink:(id)sender
{
	RFPost* post = [self selectedPostForAction];
	if (post.url.length > 0) {
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:post.url forType:NSPasteboardTypeString];
	}
}

- (IBAction) deleteSelectedPost:(id)sender
{
	RFPost* post = [self selectedPostForAction];
	if (post == nil) {
		return;
	}

	NSString* s = post.title;
	if (s.length == 0) {
		s = [post displaySummary];
		if (s.length > 20) {
			s = [s substringToIndex:20];
			s = [s stringByAppendingString:@"..."];
		}
	}

	NSAlert* sheet = [[NSAlert alloc] init];
	sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", s];
	sheet.informativeText = @"This post will be removed from your blog and the Micro.blog timeline.";
	[sheet addButtonWithTitle:@"Delete"];
	[sheet addButtonWithTitle:@"Cancel"];
	[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSAlertFirstButtonReturn) {
			[self deletePost:post];
		}
	}];
}

- (void) deletePost:(RFPost *)post
{
	NSDictionary* args = @{
		@"action": @"delete",
		@"mp-destination": [self currentDestinationUID],
		@"url": post.url
	};

	[self.progressSpinner startAnimation:nil];
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self.progressSpinner stopAnimation:nil];
			if ([self responseHasError:response]) {
				[self showMicropubError:response title:@"Error Deleting Post"];
			}
			else {
				[self fetchPosts];
			}
		});
	}];
}

- (RFPost *) selectedPostForAction
{
	NSInteger row = self.postsTableView.selectedRow;
	if (row >= 0 && row < (NSInteger)self.currentPosts.count) {
		return [self.currentPosts objectAtIndex:row];
	}
	else {
		return nil;
	}
}

- (void) delete:(id)sender
{
	if (self.view.window.firstResponder == self.categoriesTableView) {
		[self deleteSelectedCategory:sender];
	}
	else if (self.view.window.firstResponder == self.postsTableView) {
		[self deleteSelectedPost:sender];
	}
}

- (BOOL) responseHasError:(UUHttpResponse *)response
{
	if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
		return (response.parsedResponse[@"error"] != nil);
	}
	else {
		return NO;
	}
}

- (void) showMicropubError:(UUHttpResponse *)response title:(NSString *)title
{
	NSString* msg = nil;
	if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
		msg = response.parsedResponse[@"error_description"];
	}
	if (msg.length == 0) {
		msg = @"Could not update the category.";
	}

	[NSAlert rf_showOneButtonAlert:title message:msg button:@"OK" completionHandler:NULL];
}

#pragma mark -

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self setupBlogName];
	[self fetchCategories];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self fetchPosts];
}

- (BOOL) control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	#pragma unused(textView)

	if (control == self.categoryEditField) {
		if (commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
			[self commitCategoryRename:control];
			return YES;
		}
		else if (commandSelector == @selector(cancelOperation:)) {
			[self cancelCategoryRename];
			return YES;
		}
	}

	return NO;
}

- (void) controlTextDidEndEditing:(NSNotification *)notification
{
	#pragma unused(notification)
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
	if (notification.object == self.categoriesTableView) {
		if (self.editingCategoryRow >= 0 && self.categoriesTableView.selectedRow != self.editingCategoryRow) {
			[self cancelCategoryRename];
		}

		[self fetchPosts];
	}
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == self.categoriesTableView) {
		return self.categories.count;
	}
	else {
		return self.currentPosts.count;
	}
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	if (tableView == self.categoriesTableView) {
		if (row >= self.categories.count) {
			return nil;
		}

		MBCategory* category = [self.categories objectAtIndex:row];
		MBCategoryCell* cell = [tableView makeViewWithIdentifier:kCategoryCellIdentifier owner:self];
		if (cell == nil) {
			cell = [[MBCategoryCell alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, tableView.rowHeight)];
			cell.identifier = kCategoryCellIdentifier;
		}

		if (row == self.editingCategoryRow && self.editingCategory != nil) {
			[cell setupForEditingWithCategory:category target:self action:@selector(commitCategoryRename:) delegate:self];
			self.categoryEditField = cell.editField;
		}
		else {
			[cell setupWithCategory:category];
		}

		return cell;
	}
	else {
		RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];
		if (row < self.currentPosts.count) {
			RFPost* post = [self.currentPosts objectAtIndex:row];
			[cell setupWithPost:post skipPhotos:NO search:@""];
		}

		return cell;
	}
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	#pragma unused(tableView)
	#pragma unused(tableColumn)
	#pragma unused(row)

	return nil;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(editSelectedCategory:) || item.action == @selector(deleteSelectedCategory:)) {
		return ([self selectedCategoryForAction] != nil);
	}
	else if (item.action == @selector(openSelectedPost:) || item.action == @selector(deleteSelectedPost:) || item.action == @selector(openPostInBrowser:) || item.action == @selector(copyPostLink:)) {
		return ([self selectedPostForAction] != nil);
	}
	else {
		return YES;
	}
}

@end

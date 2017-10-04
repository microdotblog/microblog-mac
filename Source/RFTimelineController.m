//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

static CGFloat const kDefaultSplitViewPosition = 180.0;

@implementation RFTimelineController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Timeline"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
}

//- (void) setupTextView
//{
//	self.textView.font = [NSFont systemFontOfSize:15 weight:NSFontWeightLight];
//	self.textView.backgroundColor = [NSColor colorWithCalibratedWhite:0.973 alpha:1.000];
//}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"MenuCell" bundle:nil] forIdentifier:@"MenuCell"];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
}

- (void) setupSplitView
{
	[self.splitView setPosition:kDefaultSplitViewPosition ofDividerAtIndex:0];
	self.splitView.delegate = self;
}

- (void) setupWebView
{
	[self showTimeline:nil];
}

- (IBAction) showTimeline:(id)sender
{
	NSString* token = [[NSUserDefaults standardUserDefaults] objectForKey:@"SnippetsToken"];
	CGFloat pane_width = self.webView.bounds.size.width;
	NSInteger timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) showMentions:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) showFavorites:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return 3;
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return @"";
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	NSTableRowView* cell = [tableView makeViewWithIdentifier:@"MenuCell" owner:self];
	return cell;
}

#pragma mark -

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

@end

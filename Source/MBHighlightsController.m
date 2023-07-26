//
//  MBHighlightsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightsController.h"

#import "MBHighlight.h"
#import "MBHighlightCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "NSString+Extras.h"
#import "UUDate.h"

@implementation MBHighlightsController

- (id) init
{
	self = [super initWithNibName:@"Highlights" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupBrowser];
	
	[self fetchHighlights];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"HighlightCell" bundle:nil] forIdentifier:@"HighlightCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;

	self.view.window.initialFirstResponder = self.tableView;
}

- (void) setupBrowser
{
	NSString* browser_s = @"Open in Browser";
	
	NSURL* example_url = [NSURL URLWithString:@"https://micro.blog/"];
	NSURL* app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:example_url];
	if ([app_url.lastPathComponent containsString:@"Chrome"]) {
		browser_s = @"Open in Chrome";
	}
	else if ([app_url.lastPathComponent containsString:@"Firefox"]) {
		browser_s = @"Open in Firefox";
	}
	else if ([app_url.lastPathComponent containsString:@"Safari"]) {
		browser_s = @"Open in Safari";
	}

	self.browserMenuItem.title = browser_s;
}

- (void) fetchHighlights
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/bookmarks/highlights"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_highlights = [NSMutableArray array];
			for (NSDictionary* info in [response.parsedResponse objectForKey:@"items"]) {
				MBHighlight* h = [[MBHighlight alloc] init];
				h.highlightID = [info objectForKey:@"id"];
				h.selectionText = [info objectForKey:@"content_text"];
				h.title = [info objectForKey:@"title"];
				h.url = [info objectForKey:@"url"];
				NSString* date_s = [info objectForKey:@"date_published"];
				h.createdAt = [NSDate uuDateFromRfc3339String:date_s];
				
				[new_highlights addObject:h];
			}
			
			RFDispatchMainAsync (^{
				self.currentHighlights = new_highlights;
				[self.tableView reloadData];
				self.tableView.animator.alphaValue = 1.0;
			});
		}
	}];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

- (IBAction) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		
		NSString* s = h.selectionText;
		if (s.length > 50) {
			s = [s substringToIndex:50];
			s = [s stringByAppendingString:@"..."];
		}
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", s];
		sheet.informativeText = @"This highlight will be deleted.";
		[sheet addButtonWithTitle:@"Delete"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				// TODO: hit server to delete it, refresh
				// ...
			}
		}];
	}
}

- (IBAction) startNewPost:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		
		NSString* s;
		s = [NSString stringWithFormat:@"[%@](%@)\n\n> %@", h.title, h.url, h.selectionText];
				
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"microblog://post?text=%@", [s rf_urlEncoded]]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:h.url];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) openInBrowser:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:h.url];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:h.url forType:NSPasteboardTypeString];
	}
}

- (IBAction) copyText:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:h.selectionText forType:NSPasteboardTypeString];
	}
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(newDocument:)) {
		NSInteger row = self.tableView.selectedRow;
		if (row >= 0) {
			[item setTitle:@"New Post with Highlight"];
		}
		else {
			[item setTitle:@"New Post"];
		}
	}

	return YES;
}

- (void) newDocument:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		[self startNewPost:nil];
	}
	else {
		// try to bubble it up to the top to be handled
		[[NSApplication sharedApplication] tryToPerform:@selector(newDocument:) with:sender];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentHighlights.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBHighlightCell* cell = [tableView makeViewWithIdentifier:@"HighlightCell" owner:self];

	if (row < self.currentHighlights.count) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		[cell setupWithHighlight:h];
	}

	return cell;
}

@end

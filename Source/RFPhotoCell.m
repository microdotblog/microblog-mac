//
//  RFPhotoCell.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPhotoCell.h"

#import "RFUpload.h"
#import "MBCollection.h"
#import "RFConstants.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "NSString+Extras.h"

@implementation RFPhotoCell

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupBrowser];
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) setupForURL
{
	RFUpload* up = [[RFUpload alloc] initWithURL:self.url];
	if (![up isAudio]) {
		[[self.htmlWithoutPlayerItem menu] removeItem:self.htmlWithoutPlayerItem];
	}
}

- (void) setupForCollection:(MBCollection *)collection
{
	if (collection == nil) {
		// when we remove, save a copy to add back later
		self.copiedRemoveItem = self.removeFromCollectionItem;
		[[self.removeFromCollectionItem menu] removeItem:self.removeFromCollectionItem];
	}
	else if (self.copiedRemoveItem != nil) {
		// add saved item back to menu (if it's not in another menu)
		if (self.copiedRemoveItem.menu == nil) {
			[[self.browserMenuItem menu] insertItem:self.copiedRemoveItem atIndex:1];
		}
		
		// always update menu title
		self.copiedRemoveItem.title = [NSString stringWithFormat:@"Remove from %@", collection.name];
	}
}

- (void) disableMenu
{
	self.selectionOverlayView.menu = nil;
}

- (IBAction) promptNewPostWithSelectedPhoto:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kNewPostWithPhotoNotification object:self userInfo:@{
		kNewPostWithPhotoURLKey: self.url,
		kNewPostWithPhotoAltKey: self.alt
		
	}];
}

- (IBAction) deleteSelectedPhoto:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDeleteSelectedPhotoNotification object:self];
}

- (IBAction) removeFromCollection:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kRemoveFromCollectionNotification object:self userInfo:@{
		kRemoveFromCollectionURLKey: self.url
	}];
}

- (IBAction) openInBrowser:(id)sender
{
	NSURL* url = [NSURL URLWithString:self.url];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction) copyLink:(id)sender
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:self.url forType:NSPasteboardTypeString];
}

- (IBAction) copyHTML:(id)sender
{
	NSString* s;
	
	RFUpload* up = [[RFUpload alloc] initWithURL:self.url];
	if ([up isPhoto]) {
		if (self.alt.length > 0) {
			s = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"%@\">", self.url, self.alt];
		}
		else {
			s = [NSString stringWithFormat:@"<img src=\"%@\">", self.url];
		}
	}
	else if ([up isVideo]) {
		s = [NSString stringWithFormat:@"<video src=\"%@\" controls=\"controls\" playsinline=\"playsinline\" preload=\"none\"></video>", self.url];
	}
	else if ([up isAudio]) {
		s = [NSString stringWithFormat:@"<audio src=\"%@\" controls=\"controls\" preload=\"metadata\"></audio>", self.url];
	}
	else {
		s = [NSString stringWithFormat:@"<img src=\"%@\">", self.url];
	}
	
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:s forType:NSPasteboardTypeString];
}

- (IBAction) copyHTMLwithoutPlayer:(id)sender
{
	NSString* s = [NSString stringWithFormat:@"<audio src=\"%@\" preload=\"metadata\" style=\"display: none\"></audio>", self.url];

	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:s forType:NSPasteboardTypeString];
}

- (IBAction) copyMarkdown:(id)sender
{
	NSString* s;

	RFUpload* up = [[RFUpload alloc] initWithURL:self.url];
	if ([up isPhoto]) {
		s = [NSString stringWithFormat:@"![](%@)", self.url];
	}
	else {
		s = [NSString stringWithFormat:@"[](%@)", self.url];
	}

	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:s forType:NSPasteboardTypeString];
}

- (IBAction) getInfo:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowInfoNotification object:self userInfo:@{
		kInfoURLKey: self.url,
		kInfoTextKey: self.alt
	}];
}

@end

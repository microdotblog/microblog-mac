//
//  MBBookCell.m
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBookCell.h"

#import "MBBook.h"
#import "RFBookshelf.h"
#import "RFConstants.h"

@implementation MBBookCell

- (void) setupWithBook:(MBBook *)book inBookshelf:(RFBookshelf *)bookshelf
{
	self.book = book;
	self.bookshelf = bookshelf;
	
	self.titleField.stringValue = book.title;
	
	if ([book.authors count] > 0) {
		self.authorField.stringValue = [book.authors firstObject];
	}
	else {
		self.authorField.stringValue = @"";
	}
	
	self.coverImageView.image = book.coverImage;
	if (book.coverImage == nil) {
		self.coverImageView.image = [book cachedCover];
	}
	
	// search results don't have a book ID, show the add button
	self.addButton.hidden = (book.bookID != nil);
}

- (void) drawBackgroundInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	[self.backgroundColor set];
	NSRectFill (r);
}

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	if ([self.superview isKindOfClass:[NSTableView class]]) {
		NSTableView* table = (NSTableView *)self.superview;
		if (![table.window isKeyWindow]) {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
		else if (table.window.firstResponder == table) {
			[[NSColor selectedContentBackgroundColor] set];
		}
		else {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
	}
	
	NSRectFill (r);
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	self.optionsButton.hidden = !selected;
}

- (IBAction) addBook:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kAddBookNotification object:self userInfo:@{
		kAddBookKey: self.book,
		kAddBookBookshelfKey: self.bookshelf
	}];	
}

- (IBAction) showOptionsMenu:(id)sender
{
	NSTableView* table = (NSTableView *)[self superview];
	NSMenu* menu = table.menu;
	[menu popUpMenuPositioningItem:nil atLocation:[NSEvent mouseLocation] inView:nil];
}

@end

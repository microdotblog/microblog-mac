//
//  MBBookNoteController.m
//  Micro.blog
//
//  Created by Manton Reece on 9/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBBookNoteController.h"

#import "MBBook.h"
#import "MBNotebook.h"
#import "MBBookCoverView.h"
#import "NSAppearance+Extras.h"

@implementation MBBookNoteController

- (id) initWithBook:(MBBook *)book readingNotebook:(MBNotebook *)notebook
{
	self = [super initWithWindowNibName:@"BookNoteWindow"];
	if (self) {
		self.book = book;
		self.notebook = notebook;
	}
	
	return self;
}

- (void) awakeFromNib
{
	[self setupBook];
	[self setupColors];
	[self setupText];
}

- (void) setupBook
{
	[self.bookCoverView setupWithBook:self.book];
	[self.bookTitleField setStringValue:self.book.title];
}

- (void) setupColors
{
	// adjust text background to notebook color
	NSColor* base_color;
	if ([NSAppearance rf_isDarkMode]) {
		base_color = self.notebook.darkColor;
	}
	else {
		base_color = self.notebook.lightColor;
	}
	self.noteTextView.backgroundColor = base_color;

	// darken the base color for the book header and shared footer
	NSColor* darker_color = [base_color blendedColorWithFraction:0.05 ofColor:[NSColor blackColor]];
	self.bookHeader.fillColor = darker_color;
}

- (void) setupText
{
	[self.noteTextView setFont:[NSFont systemFontOfSize:16]];
	[self.noteTextView setTextContainerInset:NSMakeSize(10, 10)];
}

#pragma mark -

- (IBAction) addBook:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction) cancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end

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
	[self.bookTitleField setStringValue:self.book.title];
}

- (IBAction) addBook:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction) cancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end

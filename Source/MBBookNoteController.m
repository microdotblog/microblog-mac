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
#import "MBNote.h"
#import "MBBookCoverView.h"
#import "RFConstants.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "NSAppearance+Extras.h"
#import "SAMKeychain.h"

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
	self.noteTextView.delegate = self;
	self.addButton.enabled = NO;
}

#pragma mark -

- (void) textDidChange:(NSNotification *)notification
{
	NSString* s = self.noteTextView.string;
	self.addButton.enabled = (s.length > 0);
}
	
- (IBAction) addBook:(id)sender
{
	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/notes"];
	NSString* s = self.noteTextView.string;
	
	NSString* secret_key = [SAMKeychain passwordForService:@"Micro.blog Notes" account:@""];
	secret_key = [MBNote cleanKey:secret_key];
	s = [MBNote encryptText:s withKey:secret_key];
	
	NSDictionary* args = @{
		@"text": s,
		@"is_encrypted": [NSNumber numberWithBool:YES],
		@"attached_book_isbn": self.book.isbn
	};
		
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			[self.progressSpinner stopAnimation:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshNotesNotification object:self];
			[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
		});
	}];

}

- (IBAction) cancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end

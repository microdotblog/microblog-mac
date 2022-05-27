//
//  RFBookshelfCell.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFBookshelfCell.h"

#import "RFBookshelf.h"
#import "RFPhotoCell.h"
#import "MBBook.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "NSString+Extras.h"

static NSString* const kPhotoCellIdentifier = @"PhotoCell";

@implementation RFBookshelfCell

- (void) setupWithBookshelf:(RFBookshelf *)bookshelf
{
	self.bookshelf = bookshelf;
	self.titleField.stringValue = bookshelf.title;
	
	[self fetchBooks];
}

- (void) fetchBooks
{
	self.books = @[];

	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:[NSString stringWithFormat:@"/books/bookshelves/%@", self.bookshelf.bookshelfID]];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_books = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBBook* b = [[MBBook alloc] init];
				b.bookID = [item objectForKey:@"id"];
				b.title = [item objectForKey:@"title"];
				b.coverURL = [item objectForKey:@"image"];

				[new_books addObject:b];
			}
			
			RFDispatchMainAsync (^{
				self.books = new_books;
				[self.collectionView reloadData];
			});
		}
	}];
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

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.books.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	[item disableMenu];
	
	if (indexPath.item < self.books.count) {
		MBBook* b = [self.books objectAtIndex:indexPath.item];
		item.thumbnailImageView.image = b.coverImage;
	}
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(NSCollectionViewItem *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	MBBook* b = [self.books objectAtIndex:indexPath.item];

	if (b.coverImage == nil) {
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/300x/%@", [b.coverURL rf_urlEncoded]];

		[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				NSImage* img = response.parsedResponse;
				RFDispatchMain(^{
					b.coverImage = img;
					@try {
						[collectionView reloadItemsAtIndexPaths:[NSSet setWithCollectionViewIndexPath:indexPath]];
					}
					@catch (NSException* e) {
					}
				});
			}
		}];
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
}

@end

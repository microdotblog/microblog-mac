//
//  RFInstagramController.m
//  Snippets
//
//  Created by Manton Reece on 5/2/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFInstagramController.h"

#import "RFPhotoCell.h"

static NSString* const kPhotoCellIdentifier = @"PhotoCell";

@implementation RFInstagramController

- (instancetype) initWithFile:(NSString *)path
{
	self = [super initWithWindowNibName:@"Instagram"];
	if (self) {
		self.path = path;
		self.folder = [path stringByDeletingLastPathComponent];
		
		[self setupPhotos];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupSummary];
	[self setupColletionView];
}

- (void) setupPhotos
{
	NSData* d = [NSData dataWithContentsOfFile:self.path];
	NSError* e = nil;
	NSDictionary* obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
	self.photos = [obj objectForKey:@"photos"];
}

- (void) setupSummary
{
	if (self.photos.count == 1) {
		self.summaryField.stringValue = @"1 photo";
	}
	else {
		self.summaryField.stringValue = [NSString stringWithFormat:@"%lu photos", (unsigned long)self.photos.count];
	}
}

- (void) setupColletionView
{
	self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
	
	[self.collectionView registerNib:[[NSNib alloc] initWithNibNamed:@"PhotoCell" bundle:nil] forItemWithIdentifier:kPhotoCellIdentifier];
}

- (void) startProgress
{
	self.summaryField.hidden = YES;
	[self.progressBar startAnimation:nil];
}

- (IBAction) import:(id)sender
{
	[self startProgress];
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.photos.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary* photo = [self.photos objectAtIndex:indexPath.item];

//      "caption": "More basketball on TV today",
//      "path": "photos/201704/8674986dfc70767c44dc92d50e81b897.jpg",
//      "taken_at": "2017-04-16T12:08:35"

//	NSString* caption = [photo objectForKey:@"caption"];
	NSString* relative_path = [photo objectForKey:@"path"];
//	NSString* taken_at = [photo objectForKey:@"taken_at"];

	NSString* current_file = self.folder;
	NSArray* components = [relative_path componentsSeparatedByString:@"/"];
	for (NSString* filename in components) {
		current_file = [current_file stringByAppendingPathComponent:filename];
	}

	NSImage* img = [[NSImage alloc] initWithContentsOfFile:current_file];

	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	item.thumbnailImageView.image = img;
	
	return item;
}

@end

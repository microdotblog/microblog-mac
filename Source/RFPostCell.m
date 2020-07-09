//
//  RFPostCell.m
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPostCell.h"

#import "RFPhotoCell.h"
#import "RFPhoto.h"
#import "RFPost.h"
#import "UUDate.h"
#import "UUHttpSession.h"
#import "HTMLParser.h"
#import "RFMacros.h"

// https://github.com/zootreeves/Objective-C-HMTL-Parser (comments say it's MIT)

static NSString* const kPhotoCellIdentifier = @"PhotoCell";

@implementation RFPostCell

- (void) setupWithPost:(RFPost *)post
{
	self.titleField.stringValue = post.title;
	self.textField.stringValue = [post summary];
	self.dateField.stringValue = [post.postedAt uuIso8601DateString];
	self.draftField.hidden = !post.isDraft;
	
	if (post.title.length == 0) {
		self.textTopConstraint.constant = 10;
	}
	else {
		self.textTopConstraint.constant = 35;
	}
	
	NSError* error = nil;
	HTMLParser* p = [[HTMLParser alloc] initWithString:post.text error:&error];
	if (error == nil) {
		NSMutableArray* new_photos = [NSMutableArray array];
		
		HTMLNode* body = [p body];
		NSArray* img_tags = [body findChildTags:@"img"];
		for (HTMLNode* img_tag in img_tags) {
			RFPhoto* photo = [[RFPhoto alloc] init];
			photo.publishedURL = [img_tag getAttributeNamed:@"src"];
			[new_photos addObject:photo];
		}

		NSArray* video_tags = [body findChildTags:@"video"];
		for (HTMLNode* video_tag in video_tags) {
			NSString* poster_url = [video_tag getAttributeNamed:@"poster"];
			if ([poster_url length] > 0) {
				RFPhoto* photo = [[RFPhoto alloc] init];
				photo.publishedURL = poster_url;
				[new_photos addObject:photo];
			}
		}

		self.photos = new_photos;
	}

	if (self.photos.count == 0) {
		self.dateTopConstraint.constant = 5;
	}
	else {
		self.dateTopConstraint.constant = 90;
	}
	
	[self.photosCollectionView reloadData];
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.photos.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	
	if (indexPath.item < self.photos.count) {
		RFPhoto* photo = [self.photos objectAtIndex:indexPath.item];
		item.thumbnailImageView.image = photo.thumbnailImage;
	}
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(NSCollectionViewItem *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFPhoto* photo = [self.photos objectAtIndex:indexPath.item];
	RFPhotoCell* photo_item = (RFPhotoCell *)item;

	if (photo.thumbnailImage == nil) {
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/200/%@", photo.publishedURL];

		[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				NSImage* img = response.parsedResponse;
				RFDispatchMain(^{
					photo.thumbnailImage = img;
					[collectionView reloadItemsAtIndexPaths:[NSSet setWithCollectionViewIndexPath:indexPath]];
	//				photo_item.thumbnailImageView.image = img;
				});
			}
		}];
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
}

@end

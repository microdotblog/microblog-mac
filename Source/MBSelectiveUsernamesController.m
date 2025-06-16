//
//  MBSelectiveUsernamesController.m
//  Micro.blog
//
//  Created by Manton Reece on 6/16/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBSelectiveUsernamesController.h"

#import "MBSelectiveUsernameCell.h"

static NSString* const kCellIdentifier = @"SelectiveUsernameCell";

@implementation MBSelectiveUsernamesController

- (instancetype) initWithCollectionView:(NSCollectionView *)collectionView
{
	self = [super init];
	if (self) {
		self.usernames = @[ @"manton", @"hello" ];
		self.collectionView = collectionView;
		
		[self.collectionView registerNib:[[NSNib alloc] initWithNibNamed:@"SelectiveUsernameCell" bundle:nil] forItemWithIdentifier:kCellIdentifier];
		
		self.collectionView.dataSource = self;
		self.collectionView.delegate = self;
	}
	
	return self;
}

- (NSInteger) numberOfSectionsInCollectionView:(NSCollectionView *)collectionView
{
	return 1;
}

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	// one extra for "Reply all"
	return self.usernames.count + 1;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	MBSelectiveUsernameCell* cell = [collectionView makeItemWithIdentifier:kCellIdentifier forIndexPath:indexPath];

	NSString* title;
	if (indexPath.item == 0) {
		title = @"Reply all";
	}
	else {
		NSString* username = self.usernames[indexPath.item - 1];
		title = [NSString stringWithFormat:@"@%@", username];
	}
	cell.textField.stringValue = title;
	[cell setSelected:[collectionView.selectionIndexPaths containsObject:indexPath]];

	return cell;
}

- (NSSize) collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* s = (indexPath.item == 0
				   ? @"Reply all"
				   : self.usernames[indexPath.item - 1]);

	// measure text
	NSDictionary* attrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:13] };
	NSSize text_size = [s boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs].size;

	CGFloat padding;
	if (indexPath.item == 0) {
		// 8 on each side
		padding = 16;
	}
	else {
		// 8 on each side + 20 for avatar + 5 for spacing
		padding = 16 + 20 + 5;
	}
	return NSMakeSize(ceil(text_size.width + padding), 30);
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath *ip in indexPaths) {
		NSString *username = (ip.item == 0
							  ? @"all"
							  : self.usernames[ip.item - 1]);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ReplyUsernameWasSelected" object:self userInfo:@{@"username": username}];
	}
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath *ip in indexPaths) {
		NSString *username = (ip.item == 0
							  ? @"all"
							  : self.usernames[ip.item - 1]);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ReplyUsernameWasUnselected" object:self userInfo:@{@"username": username}];
	}
}

@end

//
//  RFAccountCell.m
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFAccountCell.h"

#import "RFAccount.h"
#import "RFRoundedImageView.h"

@implementation RFAccountCell

- (void) viewDidLoad
{
	[super viewDidLoad];
}

- (void) setupWithAccount:(RFAccount *)account
{
	self.account = account;
	NSString* url = account.profileImageURL;
	if (url) {
		[self.profileImageView loadFromURL:account.profileImageURL];
		self.plusField.hidden = YES;
	}
	else {
		self.profileImageView.image = nil;
		self.plusField.hidden = NO;
	}
	
	self.arrowImageView.hidden = YES;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	NSString* url = self.account.profileImageURL;
	if (url) {
		self.arrowImageView.hidden = !selected;
	}
	else {
		self.arrowImageView.hidden = YES;
	}
}

@end

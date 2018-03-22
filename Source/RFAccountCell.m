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
	NSString* url = account.profileImageURL;
	if (url) {
		[self.profileImageView loadFromURL:account.profileImageURL];
	}
	else {
		self.plusField.hidden = NO;
	}
	
	self.arrowImageView.hidden = YES;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	self.arrowImageView.hidden = !selected;
}

@end

//
//  RFPostController.m
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPostController.h"

#import "RFHighlightingTextStorage.h"

@implementation RFPostController

- (id) init
{
	self = [super initWithNibName:@"Post" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	self.textStorage = [[RFHighlightingTextStorage alloc] init];
	[self.textStorage addLayoutManager:self.textView.layoutManager];
}

@end

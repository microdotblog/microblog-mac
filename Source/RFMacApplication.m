//
//  RFMacApplication.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMacApplication.h"

@implementation RFMacApplication

- (void) showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://help.micro.blog/"]];
}

@end

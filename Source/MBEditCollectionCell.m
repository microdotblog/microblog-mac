//
//  MBEditCollectionCell.m
//  Micro.blog
//
//  Created by Manton Reece on 12/12/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBEditCollectionCell.h"

#import "MBCollection.h"
#import "RFSettings.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

@implementation MBEditCollectionCell

- (void) awakeFromNib
{
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editCollectionNotification:) name:kEditCollectionNotification object:nil];
}

- (void) editCollectionNotification:(NSNotification *)notification
{
	[self.nameField becomeFirstResponder];
}

- (NSView *) hitTest:(NSPoint)point
{
	NSPoint pt = [self convertPoint:point toView:self.nameField];
	if (NSPointInRect(pt, self.nameField.bounds)) {
		return self.nameField;
	}
	else {
		return nil;
	}
}

- (IBAction) renameCollection:(id)sender
{
	MBCollection* c = [[MBCollection alloc] init];
	c.name = [sender stringValue];
	[self updateCollection:c];
	
}

- (void) updateCollection:(MBCollection *)collection
{
	[self.progressSpinner startAnimation:nil];
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* info = @{
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid,
		@"properties": @{
			@"name": @[ collection.name ]
		}
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client postWithObject:info completion:^(UUHttpResponse *response) {
		if (![[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSLog(@"Error adding URL: %@", response.rawResponse);
		}
		
		RFDispatchMain(^{
			[self.progressSpinner stopAnimation:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kUpdateCollectionsNotification object:self];
		});
	}];
}

@end

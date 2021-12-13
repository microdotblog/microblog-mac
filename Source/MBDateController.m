//
//  MBDateController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/13/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "MBDateController.h"

#import "RFPost.h"
#import "UUDate.h"

@implementation MBDateController

- (id) init
{
	self = [super initWithWindowNibName:@"Date"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[self setupDefault];
	
	[super windowDidLoad];
}

- (void) setupDefault
{
	self.datePicker.dateValue = [NSDate date];
	self.timePicker.dateValue = [NSDate date];
}

- (IBAction) okPressed:(id)sender
{
	NSDate* d = self.datePicker.dateValue;
	NSDate* t = self.timePicker.dateValue;
	
	NSCalendar* cal = [NSCalendar currentCalendar];
	
	NSDateComponents* date_components = [cal componentsInTimeZone:cal.timeZone fromDate:d];
	NSDateComponents* time_components = [cal componentsInTimeZone:cal.timeZone fromDate:t];

	[date_components setHour:time_components.hour];
	[date_components setMinute:time_components.minute];
	[date_components setSecond:0];
	
	self.date = [date_components date];
	
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction) cancelPressed:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end

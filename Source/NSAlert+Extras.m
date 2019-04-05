//
//  NSAlert+Extras.m
//  Snippets
//
//  Created by Manton Reece on 10/15/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "NSAlert+Extras.h"

#import "RFMacros.h"

@implementation NSAlert (Extras)

+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(void (^)(NSModalResponse returnCode))handler
{
	NSAlert* alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:button];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	
	RFDispatchMainAsync (^{
		NSModalResponse response = [alert runModal];
		if (handler) {
			handler (response);
		}
	});
}

+ (void) rf_showTwoButtonAlert:(NSString *)title message:(NSString *)message okButton:(NSString *)okButton cancelButton:(NSString *)cancelButton completionHandler:(void (^)(NSModalResponse returnCode))handler
{
	NSAlert* alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:okButton];
	[alert addButtonWithTitle:cancelButton];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	
	RFDispatchMainAsync (^{
		NSModalResponse response = [alert runModal];
		if (handler) {
			handler (response);
		}
	});
}

@end

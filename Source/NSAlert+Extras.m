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
	RFDispatchMainAsync (^{
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:([button isKindOfClass:[NSString class]] && button.length > 0) ? button : @"OK"];
		[alert setMessageText:([title isKindOfClass:[NSString class]] && title.length > 0) ? title : @"Error"];
		[alert setInformativeText:([message isKindOfClass:[NSString class]] && message.length > 0) ? message : @"The request could not be completed. Please try again."];

		NSModalResponse response = [alert runModal];
		if (handler) {
			handler (response);
		}
	});
}

+ (void) rf_showTwoButtonAlert:(NSString *)title message:(NSString *)message okButton:(NSString *)okButton cancelButton:(NSString *)cancelButton completionHandler:(void (^)(NSModalResponse returnCode))handler
{
	RFDispatchMainAsync (^{
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:([okButton isKindOfClass:[NSString class]] && okButton.length > 0) ? okButton : @"OK"];
		[alert addButtonWithTitle:([cancelButton isKindOfClass:[NSString class]] && cancelButton.length > 0) ? cancelButton : @"Cancel"];
		[alert setMessageText:([title isKindOfClass:[NSString class]] && title.length > 0) ? title : @"Error"];
		[alert setInformativeText:([message isKindOfClass:[NSString class]] && message.length > 0) ? message : @"The request could not be completed. Please try again."];

		NSModalResponse response = [alert runModal];
		if (handler) {
			handler (response);
		}
	});
}

@end

//
//  NSAlert+Extras.h
//  Snippets
//
//  Created by Manton Reece on 10/15/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSAlert (Extras)

+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(void (^)(NSModalResponse returnCode))handler;
+ (void) rf_showTwoButtonAlert:(NSString *)title message:(NSString *)message okButton:(NSString *)okButton cancelButton:(NSString *)cancelButton completionHandler:(void (^)(NSModalResponse returnCode))handler;

@end

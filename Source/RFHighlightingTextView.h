//
//  RFHighlightingTextView.h
//  Snippets
//
//  Created by Manton Reece on 10/10/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFHighlightingTextView : NSTextView <NSDraggingDestination>

@property (assign, nonatomic) NSRange restoredSelection;

@end

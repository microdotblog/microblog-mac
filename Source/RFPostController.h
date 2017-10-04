//
//  RFPostController.h
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFHighlightingTextStorage;

@interface RFPostController : NSViewController

@property (strong, nonatomic) IBOutlet NSTextView* textView;

@property (strong, nonatomic) RFHighlightingTextStorage* textStorage;

@end

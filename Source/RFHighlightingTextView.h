//
//  RFHighlightingTextView.h
//  Snippets
//
//  Created by Manton Reece on 10/10/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "MBMarkdownTextView.h"

@interface RFHighlightingTextView : MBMarkdownTextView <NSDraggingDestination>

@property (assign, nonatomic) BOOL isIgnoringAutocomplete;

@end

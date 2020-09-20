//
//  NSImage+Extras.h
//  Snippets
//
//  Created by Manton Reece on 10/29/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Extras)

- (NSImage *) rf_scaleToSmallestDimension:(CGFloat)max;
- (NSImage *) rf_scaleToWidth:(CGFloat)maxWidth;
- (NSImage *) rf_scaleToHeight:(CGFloat)maxHeight;
- (NSImage *) rf_scaleToSize:(NSSize)newSize;
- (NSImage *) rf_roundImage;
+ (NSImage *) rf_imageWithSystemSymbolName:(NSString *)name accessibilityDescription:(NSString *)description;

@end

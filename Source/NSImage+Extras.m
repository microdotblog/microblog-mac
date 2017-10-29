//
//  NSImage+Extras.m
//  Snippets
//
//  Created by Manton Reece on 10/29/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "NSImage+Extras.h"

@implementation NSImage (Extras)

- (NSImage *) rf_scaleToWidth:(CGFloat)maxWidth
{
	NSSize old_size = self.size;
	if (maxWidth >= old_size.width) {
		return self;
	}

	NSSize new_size;
	new_size.width = maxWidth;
	new_size.height = maxWidth / old_size.width * old_size.height;

	return [self rf_scaleToSize:new_size];
}

- (NSImage *) rf_scaleToSize:(NSSize)newSize
{
    if (!self.isValid) {
		return nil;
    }

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
              initWithBitmapDataPlanes:NULL
                            pixelsWide:newSize.width
                            pixelsHigh:newSize.height
                         bitsPerSample:8
                       samplesPerPixel:4
                              hasAlpha:YES
                              isPlanar:NO
                        colorSpaceName:NSCalibratedRGBColorSpace
                           bytesPerRow:0
                          bitsPerPixel:0];
    rep.size = newSize;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
    [self drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage addRepresentation:rep];
    return newImage;
}

@end

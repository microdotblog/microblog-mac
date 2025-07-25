//
//  RFAccountPopoverBox.h
//  Snippets
//
//  Created by Manton Reece on 3/24/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFAccountPopoverBox : NSBox

@property (strong, nonatomic) IBOutlet NSLayoutConstraint* triangleWidthConstraint;

@property (strong, nonatomic) NSTrackingArea* customTrackingArea;
@property (strong, nonatomic) NSColor* originalLightColor;
@property (strong, nonatomic) NSColor* savedFillColor;

@end

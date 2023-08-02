//
//  MBStatusBubbleView.h
//  Micro.blog
//
//  Created by Manton Reece on 6/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBStatusBubbleView : NSView

@property (strong, nonatomic) NSTrackingArea* customTrackingArea;
@property (strong, nonatomic) NSColor* fillColor;
@property (strong, nonatomic) IBOutlet NSTextField* statusMessageTextField;

@end

NS_ASSUME_NONNULL_END

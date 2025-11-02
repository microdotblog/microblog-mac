//
//  MBMovieCell.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBMovie;

@interface MBMovieCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSImageView* posterImageView;
@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextField* subtitleField;

- (void) setupWithMovie:(MBMovie *)movie;

@end

NS_ASSUME_NONNULL_END

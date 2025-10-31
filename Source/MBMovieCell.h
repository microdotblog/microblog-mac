//
//  MBMovieCell.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBMovieCell : NSTableRowView

- (void) setupWithMovie:(id)movie;

@end

NS_ASSUME_NONNULL_END

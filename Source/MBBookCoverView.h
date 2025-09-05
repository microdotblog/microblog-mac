//
//  MBBookCoverView.h
//  Micro.blog
//
//  Created by Manton Reece on 9/5/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBookCoverView : NSImageView

- (void) setupWithISBN:(NSString *)isbn;

@end

NS_ASSUME_NONNULL_END

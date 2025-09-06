//
//  MBBookCoverView.h
//  Micro.blog
//
//  Created by Manton Reece on 9/5/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBBook;

@interface MBBookCoverView : NSImageView

- (void) setupWithBook:(MBBook *)book;
- (void) setupWithISBN:(NSString *)isbn;

@end

NS_ASSUME_NONNULL_END

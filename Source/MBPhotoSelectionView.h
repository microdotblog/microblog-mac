//
//  MBPhotoSelectionView.h
//  Micro.blog
//
//  Created by Manton Reece on 6/2/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class RFPhotoCell;

@interface MBPhotoSelectionView : NSView

@property (strong, nonatomic) IBOutlet RFPhotoCell* photoCell;

@end

NS_ASSUME_NONNULL_END

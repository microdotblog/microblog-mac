//
//  RFWordPressExportController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/7/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFExportController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RFWordPressExportController : RFExportController

@property (strong) NSMutableArray* posts;
@property (strong) NSMutableArray* uploads;

@end

NS_ASSUME_NONNULL_END

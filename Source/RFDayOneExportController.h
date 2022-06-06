//
//  RFDayOneExportController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFExportController.h"

@class RFAccount;

NS_ASSUME_NONNULL_BEGIN

@interface RFDayOneExportController : RFExportController

@property (strong, nonatomic, readonly) RFAccount* account;

- (instancetype) initWithAccount:(RFAccount *)account;
+ (BOOL) checkForDayOne;

@end

NS_ASSUME_NONNULL_END

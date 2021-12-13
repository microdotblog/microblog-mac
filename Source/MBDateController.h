//
//  MBDateController.h
//  Micro.blog
//
//  Created by Manton Reece on 12/13/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBDateController : NSWindowController

@property (strong, nonatomic) IBOutlet NSDatePicker* datePicker;
@property (strong, nonatomic) IBOutlet NSDatePicker* timePicker;

@property (strong, nonatomic) NSDate* date;

@end

NS_ASSUME_NONNULL_END

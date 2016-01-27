//
//  PaddleToolKit.h
//  Paddle
//
//  Created by Louis Harwood on 12/06/2015.
//  Copyright (c) 2015 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PTKHappiness;
@class PTKRate;
@class PTKFeedback;
@class PTKEmail;
@class PTKThanks;

@interface PaddleToolKit : NSObject {
    PTKHappiness *happinessView;
    PTKRate *rateView;
    PTKFeedback *feedbackView;
    PTKEmail *emailView;
    PTKThanks *thanksView;
}

@property (nonatomic, strong) PTKHappiness *happinessView;
@property (nonatomic, strong) PTKRate *rateView;
@property (nonatomic, strong) PTKFeedback *feedbackView;
@property (nonatomic, strong) PTKEmail *emailView;
@property (nonatomic, strong) PTKThanks *thanksView;

+ (PaddleToolKit *)sharedInstance;
- (void)presentHappinessViewWithSchedule:(NSString *)schedule message:(NSString *)message;
- (void)presentEmailSubscribePromptWithSchedule:(NSString *)schedule message:(NSString *)message;
- (void)presentFeedbackViewWithSchedule:(NSString *)schedule message:(NSString *)message label:(NSString *)label;
- (void)presentRatingViewWithSchedule:(NSString *)schedule message:(NSString *)message;

- (void)presentAppStoreRatingWithSchedule:(NSString *)schedule appId:(NSString *)appId;

@end

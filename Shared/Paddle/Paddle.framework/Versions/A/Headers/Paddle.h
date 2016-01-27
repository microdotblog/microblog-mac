//
//  Paddle.h
//  Paddle Test
//
//  Created by Louis Harwood on 10/05/2013.
//  Copyright (c) 2015 Paddle. All rights reserved.
//  Version: 2.3.6

#define kPADProductName @"name"
#define kPADOnSale @"on_sale"
#define kPADDiscount @"discount_line"
#define kPADUsualPrice @"base_price"
#define kPADCurrentPrice @"current_price"
#define kPADCurrency @"price_currency"
#define kPADDevName @"vendor_name"
#define kPADTrialText @"text"
#define kPADImage @"image"
#define kPADTrialDuration @"duration"
#define kPADProductImage @"default_image"

#define kPADActivated @"Activated"
#define kPADContinue @"Continue"

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@protocol PaddleDelegate <NSObject>

@optional
- (void)licenceActivated;
- (void)licenceDeactivated:(BOOL)deactivated message:(NSString *)deactivateMessage;
- (void)paddleDidFailWithError:(NSError *)error;
- (BOOL)willShowBuyWindow;
- (void)productDataReceived;
@end

@class PADProductWindowController;
@class PADActivateWindowController;
@class PADBuyWindowController;

@interface Paddle : NSObject {
    PADProductWindowController *productWindow;
    PADActivateWindowController *activateWindow;
    PADBuyWindowController *buyWindow;
    NSWindow *devMainWindow;
    
    BOOL isTimeTrial;
    BOOL isOpen;
    BOOL canForceExit;
    BOOL willShowLicensingWindow;
    BOOL hasTrackingStarted;
    BOOL willSimplifyViews;
    BOOL willShowActivationAlert;
    BOOL willContinueAtTrialEnd;
    
    #if !__has_feature(objc_arc)
    id <PaddleDelegate> delegate;
    #endif
}

@property (assign) id <PaddleDelegate> delegate;

@property (nonatomic, retain) PADProductWindowController *productWindow;
@property (nonatomic, retain) PADActivateWindowController *activateWindow;
@property (nonatomic, retain) PADBuyWindowController *buyWindow;
@property (nonatomic, retain) NSWindow *devMainWindow;

@property (assign) BOOL isTimeTrial;
@property (assign) BOOL isOpen;
@property (assign) BOOL canForceExit;
@property (assign) BOOL willShowLicensingWindow;
@property (assign) BOOL hasTrackingStarted;
@property (assign) BOOL willSimplifyViews;
@property (assign) BOOL willShowActivationAlert;
@property (assign) BOOL willContinueAtTrialEnd;


+ (Paddle *)sharedInstance;
- (void)startLicensing:(NSString *)apiKey vendorId:(NSString *)vendorId productId:(NSString *)productId timeTrial:(BOOL)timeTrial productInfo:(NSDictionary *)productInfo withWindow:(NSWindow *)mainWindow __deprecated;
- (void)startLicensing:(NSDictionary *)productInfo timeTrial:(BOOL)timeTrial withWindow:(NSWindow *)mainWindow;
- (void)startPurchase;

- (NSNumber *)daysRemainingOnTrial;
- (BOOL)productActivated;
- (void)showLicencing;
- (NSString *)activatedLicenceCode;
- (NSString *)activatedEmail;

- (void)deactivateLicence;


- (void)setApiKey:(NSString *)apiKey;
- (void)setVendorId:(NSString *)vendorId;
- (void)setProductId:(NSString *)productId;

- (void)setCustomProductHeading:(NSString *)productHeading;
- (void)disableTrial:(BOOL)trialSetting;
- (void)disableLicenseMigration;
- (void)disableTrialResetOnDeactivate;
- (void)resetTrialOnVersionUpdateForMajorOnly:(BOOL)onlyMajor;
- (void)overridePrice:(NSString *)price;


@end

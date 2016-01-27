//
//  PSKReceipt.h
//  PaddleIAPDemo
//
//  Created by Louis Harwood on 15/05/2014.
//  Copyright (c) 2014 Louis Harwood. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PSKReceiptDelegate <NSObject>

- (void)verificationSuccess:(id)receipt;
- (void)verificationFail:(id)receipt;

@end

@interface PSKReceipt : NSObject {
    NSMutableData *receivedData;
    NSString *productId;
    NSString *token;
    NSString *userId;
    NSString *receiptId;
    NSDate *lastActivated;
    NSString *userEmail;
}

@property (assign) id <PSKReceiptDelegate> delegate;
@property (nonatomic, retain) NSMutableData *receivedData;

@property (copy) NSString *productId;
@property (copy) NSString *token;
@property (copy) NSString *userId;
@property (copy) NSString *receiptId;
@property (nonatomic, retain) NSDate *lastActivated;
@property (copy) NSString *userEmail;

- (void)verify;
- (void)store;

@end

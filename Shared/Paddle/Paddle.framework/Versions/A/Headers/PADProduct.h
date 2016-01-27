//
//  PADProduct.h
//  PaddleSample
//
//  Created by Louis Harwood on 27/04/2013.
//  Copyright (c) 2014 Avalore. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PADProductDelegate <NSObject>

- (void)productInfoReceived;
- (void)productInfoError:(NSString *)errorCode withMessage:(NSString *)errorMessage;

@end

@interface PADProduct : NSObject <NSURLConnectionDelegate> {
    NSMutableData *receivedData;
}

@property (assign) id <PADProductDelegate> delegate;

- (void)productInfo:(NSString *)productId apiKey:(NSString *)apiKey vendorId:(NSString *)vendorId;

@end

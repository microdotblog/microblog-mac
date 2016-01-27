//
//  PaddleStoreKit.h
//  PaddleIAPDemo
//
//  Created by Louis Harwood on 10/05/2014.
//  Copyright (c) 2014 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSKReceipt.h"

typedef enum productTypes
{
    PSKConsumableProduct,
    PSKNonConsumableProduct
} ProductType;

@protocol PaddleStoreKitDelegate <NSObject>

- (void)PSKProductPurchased:(PSKReceipt *)transactionReceipt;
- (void)PSKDidFailWithError:(NSError *)error;
- (void)PSKDidCancel;

@optional
- (void)PSKProductsReceived:(NSArray *)products;

@end

@class PSKPurchaseWindowController;
@class PSKStoreWindowController;
@class PSKProductWindowController;
@class PSKProductController;

@interface PaddleStoreKit : NSObject {
    id <PaddleStoreKitDelegate> __unsafe_unretained delegate;
    PSKPurchaseWindowController *purchaseWindow;
    PSKStoreWindowController *storeWindow;
    PSKProductWindowController *productWindow;
    PSKProductController *productController;
}

@property (assign) id <PaddleStoreKitDelegate> delegate;
@property (nonatomic, retain) PSKPurchaseWindowController *purchaseWindow;
@property (nonatomic, retain) PSKStoreWindowController *storeWindow;
@property (nonatomic, retain) PSKProductWindowController *productWindow;
@property (nonatomic, retain) PSKProductController *productController;

+ (PaddleStoreKit *)sharedInstance;

//Store
- (void)showStoreView;
- (void)showStoreViewForProductType:(ProductType)productType;
- (void)showStoreViewForProductIds:(NSArray *)productIds;


//Product
- (void)showProduct:(NSString *)productId;
- (void)allProducts;

//Purchase
- (void)purchaseProduct:(NSString *)productId;

//Receipts
- (NSArray *)validReceipts;
- (PSKReceipt *)receiptForProductId:(NSString *)productId;



@end

//
//  PSKProduct.h
//  Paddle
//
//  Created by Louis Harwood on 25/11/2014.
//  Copyright (c) 2014 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PSKProduct : NSObject {
    NSString *productId;
    NSString *name;
    NSString *currency;
    NSString *price;
    NSString *type;
    NSString *productDescription;
    NSString *icon;
}

@property (copy) NSString *productId;
@property (copy) NSString *name;
@property (copy) NSString *currency;
@property (copy) NSString *price;
@property (copy) NSString *type;
@property (copy) NSString *productDescription;
@property (copy) NSString *icon;

@end

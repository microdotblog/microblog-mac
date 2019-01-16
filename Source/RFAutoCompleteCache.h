//
//  RFAutoCompleteCache.h
//  Snippets
//
//  Created by Jonathan Hays on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFAutoCompleteCache : NSObject

+ (void) addAutoCompleteString:(NSString*)string;
+ (void) findAutoCompleteFor:(NSString*)string completion:(void (^)(NSArray* results))completion;

@end

NS_ASSUME_NONNULL_END

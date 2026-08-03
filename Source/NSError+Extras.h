//
//  NSError+Extras.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

@interface NSError (Extras)

- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response;

@end

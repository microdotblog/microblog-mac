//
//  MBDistributedWorkController.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBDistributedWorkController : NSObject

- (void) start;
- (void) stop;
- (void) checkForWork:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

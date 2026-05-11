//
//  MBBackupsController.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBackupsController : NSObject

- (void) start;
- (void) checkForBackup:(nullable id)sender;
- (void) cancelBackup;

@end

NS_ASSUME_NONNULL_END

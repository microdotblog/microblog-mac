//
//  MBLogFile.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBLogFile : NSObject

+ (void) logText:(NSString *)text toName:(NSString *)name;
+ (void) logFields:(NSArray *)fields toName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END

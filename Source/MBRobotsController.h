//
//  MBRobotsController.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MBRobotsDownloadProgressBlock)(BOOL indeterminate, double progress, NSString* detail);
typedef void (^MBRobotsDownloadCompletionBlock)(BOOL success, BOOL cancelled, NSError* _Nullable error);

@interface MBRobotsController : NSObject

@property (assign, nonatomic, readonly) BOOL isDownloading;

+ (BOOL) isSupportedMachine;

- (void) startDownloadingModelWithProgress:(MBRobotsDownloadProgressBlock)progressBlock completion:(MBRobotsDownloadCompletionBlock)completionBlock;
- (void) cancelDownload;

@end

NS_ASSUME_NONNULL_END

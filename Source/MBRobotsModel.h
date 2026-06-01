//
//  MBRobotsModel.h
//  Micro.blog
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const MBRobotsModelBaseURLString;

@interface MBRobotsModel : NSObject

@property (copy, nonatomic) NSString* modelFolderPath;

- (instancetype) initWithModelFolderPath:(NSString *)modelFolderPath;

+ (NSArray<NSString *> *) modelFilenames;
+ (NSArray<NSString *> *) largeModelFilenames;
+ (NSString *) localModelFolderPath;
+ (BOOL) isLocalModelAvailable;
+ (unsigned long long) localModelStorageBytes;
+ (void) runPrompt:(NSString *)string completion:(void (^)(NSString* result))completion;
+ (void) preloadModelWithCompletion:(void (^)(BOOL success))completion;
+ (void) unloadModelWithCompletion:(void (^)(void))completion;
+ (void) deleteLocalModelFiles;

@end

NS_ASSUME_NONNULL_END

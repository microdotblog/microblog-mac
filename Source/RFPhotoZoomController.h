//
//  RFPhotoZoomController.h
//  Snippets
//
//  Created by Manton Reece on 1/10/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPhotoZoomController : NSWindowController <NSWindowDelegate>

@property (strong, nonatomic) NSString* photoURL;
@property (strong, nonatomic) NSString* photoAlt;
@property (assign, nonatomic) BOOL isAllowCopy;
@property (strong, nonatomic, readonly, nullable) NSURL* imageURL;

+ (nullable NSURL *) normalizedImageURL:(nullable NSURL *)imageURL;
- (instancetype) initWithURL:(NSString *)photoURL altText:(nullable NSString *)photoAlt allowCopy:(BOOL)allowCopy;
- (IBAction) copyHTML:(id)sender;

@end

NS_ASSUME_NONNULL_END

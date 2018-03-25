//
//  RFRoundedImageView.h
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFRoundedImageView : NSImageView

- (void) loadFromURL:(NSString *)url;
- (void) loadFromURL:(NSString *)url completion:(void (^)(void))handler;

@end

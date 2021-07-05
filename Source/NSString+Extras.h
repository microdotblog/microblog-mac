//
//  NSString+Extras.h
//  Snippets
//
//  Created by Manton Reece on 8/26/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Extras)

- (NSNumber *) rf_numberValue;
- (NSString *) rf_urlEncoded;
- (NSString *) rf_stripHTML;
- (NSString *) rf_stringEscapingQuotes;

@end

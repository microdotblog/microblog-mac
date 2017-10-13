//
//  RFXMLRSDParser.h
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RFXMLRSDParser : NSObject <NSXMLParserDelegate>

@property (strong, nonatomic) NSMutableArray* foundEndpoints; // NSDictionary with XML attributes

+ (RFXMLRSDParser *) parsedResponseFromData:(NSData *)data;

@end

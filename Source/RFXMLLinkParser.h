//
//  RFXMLLinkParser.h
//  Micro.blog
//
//  Created by Manton Reece on 2/27/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RFXMLLinkParser : NSObject <NSXMLParserDelegate>

@property (strong, nonatomic) NSString* relValue;
@property (strong, nonatomic) NSMutableArray* foundURLs;

+ (RFXMLLinkParser *) parsedResponseFromData:(NSData *)data withRelValue:(NSString *)relValue;

@end

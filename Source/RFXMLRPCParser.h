//
//  RFXMLRPCParser.h
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RFXMLElementStack;

@interface RFXMLRPCParser : NSObject <NSXMLParserDelegate>

@property (strong, nonatomic) RFXMLElementStack* responseStack;
@property (strong, nonatomic) NSMutableArray* responseParams;
@property (strong, nonatomic) NSDictionary* responseFault;
@property (strong, nonatomic) NSMutableString* currentMemberName;
@property (strong, nonatomic) NSString* finishedMemberName;
@property (strong, nonatomic) id currentValue;
@property (assign, nonatomic) BOOL isProcessingString;

+ (RFXMLRPCParser *) parsedResponseFromData:(NSData *)data;

@end

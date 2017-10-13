//
//  RFXMLRSDParser.m
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFXMLRSDParser.h"

@implementation RFXMLRSDParser

- (instancetype) init
{
	self = [super init];
	if (self) {
		self.foundEndpoints = [NSMutableArray array];
	}
	
	return self;
}

+ (RFXMLRSDParser *) parsedResponseFromData:(NSData *)data
{
	NSXMLParser* parser = [[NSXMLParser alloc] initWithData:data];
	RFXMLRSDParser* rsd = [[RFXMLRSDParser alloc] init];
	parser.delegate = rsd;
	[parser parse];
	return rsd;
}

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"api"]) {
		[self.foundEndpoints addObject:attributeDict];
	}
}

@end

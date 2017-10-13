//
//  RFXMLRPCParser.m
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFXMLRPCParser.h"

#import "RFXMLElementStack.h"

@implementation RFXMLRPCParser

- (instancetype) init
{
	self = [super init];
	if (self) {
		self.responseParams = [NSMutableArray array];
		self.responseStack = [[RFXMLElementStack alloc] init];
	}
	
	return self;
}

+ (RFXMLRPCParser *) parsedResponseFromData:(NSData *)data
{
	NSXMLParser* parser = [[NSXMLParser alloc] initWithData:data];
	RFXMLRPCParser* xmlrpc = [[RFXMLRPCParser alloc] init];
	parser.delegate = xmlrpc;
	[parser parse];
	return xmlrpc;
}

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"params"]) {
	}
	else if ([elementName isEqualToString:@"param"]) {
	}
	else if ([elementName isEqualToString:@"value"]) {
	}
	else if ([elementName isEqualToString:@"array"]) {
		self.currentValue = [NSMutableArray array];
		[self.responseStack push:self.currentValue];
	}
	else if ([elementName isEqualToString:@"struct"]) {
		self.currentValue = [NSMutableDictionary dictionary];
		[self.responseStack push:self.currentValue];
	}
	else if ([elementName isEqualToString:@"name"]) {
		self.currentMemberName = [NSMutableString string];
	}
	else if ([elementName isEqualToString:@"string"]) {
		self.currentValue = [NSMutableString string];
		self.isProcessingString = YES;
	}
	else if ([elementName isEqualToString:@"int"]) {
		self.currentValue = [NSMutableString string];
		self.isProcessingString = YES;
	}
	else if ([elementName isEqualToString:@"i4"]) {
		self.currentValue = [NSMutableString string];
		self.isProcessingString = YES;
	}
    else if ([elementName isEqualToString:@"boolean"]) {
		self.currentValue = [NSMutableString string];
		self.isProcessingString = YES;
    }
}

- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (self.currentMemberName) {
		[self.currentMemberName appendString:string];
	}
	else if (self.isProcessingString) {
		[self.currentValue appendString:string];
	}
}

- (void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"param"]) {
		[self.responseParams addObject:self.currentValue];
	}
	else if ([elementName isEqualToString:@"fault"]) {
		self.responseFault = self.currentValue;
	}
	else if ([elementName isEqualToString:@"array"]) {
		self.currentValue = [self.responseStack pop];
	}
	else if ([elementName isEqualToString:@"struct"]) {
		self.currentValue = [self.responseStack pop];
	}
	else if ([elementName isEqualToString:@"value"]) {
		NSMutableArray* current_array = [self.responseStack peek];
		if ([current_array isKindOfClass:[NSMutableArray class]]) {
			[current_array addObject:self.currentValue];
		}
	}
	else if ([elementName isEqualToString:@"member"]) {
		NSMutableDictionary* current_struct = [self.responseStack peek];
		current_struct[self.finishedMemberName] = self.currentValue;
	}
	else if ([elementName isEqualToString:@"name"]) {
		self.finishedMemberName = [self.currentMemberName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		self.currentMemberName = nil;
	}
	else if ([elementName isEqualToString:@"int"]) {
		NSString* s = [self.currentValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		self.currentValue = [NSNumber numberWithInteger:[s integerValue]];
		self.isProcessingString = NO;
	}
	else if ([elementName isEqualToString:@"boolean"]) {
		NSString* s = [self.currentValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		self.currentValue = [NSNumber numberWithInteger:[s integerValue]];
		self.isProcessingString = NO;
	}
	else if ([elementName isEqualToString:@"string"]) {
		NSString* s = [self.currentValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		self.currentValue = s;
		self.isProcessingString = NO;
	}
}

@end

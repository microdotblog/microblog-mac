//
//  RFXMLLinkParser.m
//  Micro.blog
//
//  Created by Manton Reece on 2/27/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFXMLLinkParser.h"

#import "CTidy.h"

@implementation RFXMLLinkParser

- (instancetype) init
{
	self = [super init];
	if (self) {
		self.relValue = @"";
		self.foundURLs = [NSMutableArray array];
	}
	
	return self;
}

+ (RFXMLLinkParser *) parsedResponseFromData:(NSData *)data withRelValue:(NSString *)relValue;
{
	CTidy* tidy = [[CTidy alloc] init];
	NSString* response_s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString* cleaned_s = [tidy tidyHTMLString:response_s encoding:@"UTF8" error:nil];
	
	NSXMLParser* parser = [[NSXMLParser alloc] initWithData:[cleaned_s dataUsingEncoding:NSUTF8StringEncoding]];
	RFXMLLinkParser* link = [[RFXMLLinkParser alloc] init];
	link.relValue = relValue;
	parser.delegate = link;
	[parser parse];
	return link;
}

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"link"]) {
		NSString* rel = [attributeDict objectForKey:@"rel"];
		if ([rel isEqualToString:self.relValue]) {
			NSString* href = [attributeDict objectForKey:@"href"];
			if (href) {
				[self.foundURLs addObject:href];
			}
		}
	}
}

@end

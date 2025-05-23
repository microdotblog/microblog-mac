//
//  HTMLNode+Mutating.m
//  Micro.blog
//
//  Created by Manton Reece on 5/23/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "HTMLNode+Mutating.h"

#import <libxml/HTMLparser.h>
#import <libxml/HTMLtree.h>

@implementation HTMLNode (Mutating)

- (void) detach
{
	// Unlink this node from its parent; does not free its siblings or children.
	xmlUnlinkNode(_node);
}

- (void) removeChild:(HTMLNode *)child
{
	// Unlink and free the child’s entire subtree
	xmlUnlinkNode(child->_node);
	xmlFreeNode(child->_node);
}

- (void) setRawContents:(NSString *)html
{
	// 1) Remove all existing children
	xmlNodePtr kid = _node->children;
	while (kid) {
		xmlNodePtr next = kid->next;
		xmlUnlinkNode(kid);
		xmlFreeNode(kid);
		kid = next;
	}

	// 2) Parse the new HTML fragment into a temporary document
	const char *utf8 = [html UTF8String];
	htmlParserCtxtPtr ctxt = htmlCreateMemoryParserCtxt(utf8, (int)strlen(utf8));
	htmlParseDocument(ctxt);
	xmlDocPtr fragDoc = ctxt->myDoc;
	
	// 3) Import each parsed child node into our real document under _node
	xmlNodePtr fragRoot = xmlDocGetRootElement(fragDoc);
	for (xmlNodePtr c = fragRoot->children; c; c = c->next) {
		// copy the node (1 == recursive copy) then add it
		xmlAddChild(_node, xmlCopyNode(c, 1));
	}

	// 4) Clean up the temporary parser/doc
	xmlFreeDoc(fragDoc);
	htmlFreeParserCtxt(ctxt);
}

@end

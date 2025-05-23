//
//  HTMLNode+Mutating.h
//  Micro.blog
//
//  Created by Manton Reece on 5/23/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTMLNode (Mutating)

// Unlink this node from its parent (but don’t free it)
- (void) detach;

// Remove a specific child node
- (void) removeChild:(HTMLNode *)child;

// Replace *all* of this node’s existing children with the given HTML fragment
- (void) setRawContents:(NSString *)html;

@end

NS_ASSUME_NONNULL_END

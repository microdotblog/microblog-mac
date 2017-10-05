//
//  RFMacros.h
//  Snippets
//
//  Created by Manton Reece on 8/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#define RFDispatchThread(the_block) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), the_block)
#define RFDispatchMain(the_block) dispatch_sync(dispatch_get_main_queue(), the_block)
#define RFDispatchMainAsync(the_block) dispatch_async(dispatch_get_main_queue(), the_block)
#define RFDispatchSeconds(seconds, the_block) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), the_block)


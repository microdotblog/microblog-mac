//
//  MBNotesDatabase.h
//  Micro.blog
//
//  Created by Manton Reece on 5/21/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

NS_ASSUME_NONNULL_BEGIN

@class MBNote;

@interface MBNotesDatabase : FMDatabase

+ (NSString *) databasePath;

- (nullable instancetype) init;
- (BOOL) createTables;

- (NSDictionary *) recordFromNote:(MBNote *)note;
- (MBNote *) noteFromRecord:(NSDictionary *)record;
- (MBNote *) noteFromResultSet:(FMResultSet *)resultSet;

- (BOOL) saveNote:(MBNote *)note;
- (BOOL) saveNotes:(NSArray *)notes;
- (nullable MBNote *) noteWithID:(NSNumber *)noteID;

@end

NS_ASSUME_NONNULL_END

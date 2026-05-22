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
+ (BOOL) databaseExists;

- (nullable instancetype) init;
- (BOOL) createTables;

- (NSDictionary *) recordFromNote:(MBNote *)note;
- (MBNote *) noteFromRecord:(NSDictionary *)record;
- (MBNote *) noteFromResultSet:(FMResultSet *)resultSet;

- (BOOL) saveNote:(MBNote *)note;
- (BOOL) saveNotes:(NSArray *)notes;
- (BOOL) deleteNoteWithID:(NSNumber *)noteID;
- (BOOL) deleteNotesWithNotebookID:(NSNumber *)notebookID notInNoteIDs:(NSSet *)noteIDs;
- (nullable MBNote *) noteWithID:(NSNumber *)noteID;
- (NSArray *) notesWithNotebookID:(NSNumber *)notebookID;

@end

NS_ASSUME_NONNULL_END

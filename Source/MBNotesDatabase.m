//
//  MBNotesDatabase.m
//  Micro.blog
//
//  Created by Manton Reece on 5/21/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBNotesDatabase.h"

#import "MBNote.h"

static NSString* const kNotesTableSQL = @"CREATE TABLE IF NOT EXISTS notes ("
	"id INTEGER PRIMARY KEY, "
	"notebook_id INTEGER, "
	"text TEXT, "
	"created_at REAL, "
	"updated_at REAL, "
	"is_encrypted INTEGER, "
	"is_shared INTEGER, "
	"shared_url TEXT, "
	"attached_book_isbn TEXT, "
	"attached_book_title TEXT"
	")";

static NSString* const kNotesUpdatedAtIndexSQL = @"CREATE INDEX IF NOT EXISTS updated_at_index ON notes (notebook_id, updated_at DESC)";

@implementation MBNotesDatabase

+ (NSString *) databasePath
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSError* error = nil;
	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	[[NSFileManager defaultManager] createDirectoryAtPath:microblog_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* databases_folder = [microblog_folder stringByAppendingPathComponent:@"Databases"];
	[[NSFileManager defaultManager] createDirectoryAtPath:databases_folder withIntermediateDirectories:YES attributes:nil error:&error];

	return [databases_folder stringByAppendingPathComponent:@"Notes.db"];
}

+ (BOOL) databaseExists
{
	return [[NSFileManager defaultManager] fileExistsAtPath:[self databasePath]];
}

- (instancetype) init
{
	self = [super initWithPath:[[self class] databasePath]];
	if (self) {
		[self open];
		[self createTables];
	}

	return self;
}

- (BOOL) createTables
{
	if (![self executeUpdate:kNotesTableSQL]) {
		return NO;
	}
	if (![self executeUpdate:kNotesUpdatedAtIndexSQL]) {
		return NO;
	}

	return YES;
}

- (NSDictionary *) recordFromNote:(MBNote *)note
{
	NSMutableDictionary* record = [NSMutableDictionary dictionary];

	if (note.noteID) {
		record[@"id"] = note.noteID;
	}
	if (note.notebookID) {
		record[@"notebook_id"] = note.notebookID;
	}
	if (note.text) {
		record[@"text"] = note.text;
	}
	if (note.createdAt) {
		record[@"created_at"] = @([note.createdAt timeIntervalSince1970]);
	}
	if (note.updatedAt) {
		record[@"updated_at"] = @([note.updatedAt timeIntervalSince1970]);
	}
	record[@"is_encrypted"] = @(note.isEncrypted);
	record[@"is_shared"] = @(note.isShared);
	if (note.sharedURL) {
		record[@"shared_url"] = note.sharedURL;
	}
	if (note.attachedBookISBN) {
		record[@"attached_book_isbn"] = note.attachedBookISBN;
	}
	if (note.attachedBookTitle) {
		record[@"attached_book_title"] = note.attachedBookTitle;
	}

	return record;
}

- (MBNote *) noteFromRecord:(NSDictionary *)record
{
	MBNote* note = [[MBNote alloc] init];

	note.noteID = [record objectForKey:@"id"];
	note.notebookID = [record objectForKey:@"notebook_id"];
	note.text = [record objectForKey:@"text"];
	note.createdAt = [self dateFromRecordValue:[record objectForKey:@"created_at"]];
	note.updatedAt = [self dateFromRecordValue:[record objectForKey:@"updated_at"]];
	note.isEncrypted = [[record objectForKey:@"is_encrypted"] boolValue];
	note.isShared = [[record objectForKey:@"is_shared"] boolValue];
	note.sharedURL = [record objectForKey:@"shared_url"];
	note.attachedBookISBN = [record objectForKey:@"attached_book_isbn"];
	note.attachedBookTitle = [record objectForKey:@"attached_book_title"];

	return note;
}

- (MBNote *) noteFromResultSet:(FMResultSet *)resultSet
{
	MBNote* note = [[MBNote alloc] init];

	note.noteID = @([resultSet longLongIntForColumn:@"id"]);
	note.notebookID = @([resultSet longLongIntForColumn:@"notebook_id"]);
	note.text = [resultSet stringForColumn:@"text"];
	note.createdAt = [self dateFromTimestamp:[resultSet doubleForColumn:@"created_at"]];
	note.updatedAt = [self dateFromTimestamp:[resultSet doubleForColumn:@"updated_at"]];
	note.isEncrypted = [resultSet boolForColumn:@"is_encrypted"];
	note.isShared = [resultSet boolForColumn:@"is_shared"];
	note.sharedURL = [resultSet stringForColumn:@"shared_url"];
	note.attachedBookISBN = [resultSet stringForColumn:@"attached_book_isbn"];
	note.attachedBookTitle = [resultSet stringForColumn:@"attached_book_title"];

	return note;
}

- (BOOL) saveNote:(MBNote *)note
{
	if (note.noteID == nil) {
		return NO;
	}

	return [self executeUpdate:@"INSERT OR REPLACE INTO notes "
		"(id, notebook_id, text, created_at, updated_at, is_encrypted, is_shared, shared_url, attached_book_isbn, attached_book_title) "
		"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		note.noteID,
		[self dbValue:note.notebookID],
		[self dbValue:note.text],
		[self dbValue:[self timestampFromDate:note.createdAt]],
		[self dbValue:[self timestampFromDate:note.updatedAt]],
		@(note.isEncrypted),
		@(note.isShared),
		[self dbValue:note.sharedURL],
		[self dbValue:note.attachedBookISBN],
		[self dbValue:note.attachedBookTitle]];
}

- (BOOL) saveNotes:(NSArray *)notes
{
	BOOL did_save = YES;

	[self beginTransaction];
	for (MBNote* note in notes) {
		if (![self saveNote:note]) {
			did_save = NO;
			break;
		}
	}

	if (did_save) {
		[self commit];
	}
	else {
		[self rollback];
	}

	return did_save;
}

- (BOOL) deleteNoteWithID:(NSNumber *)noteID
{
	if (noteID == nil) {
		return NO;
	}

	return [self executeUpdate:@"DELETE FROM notes WHERE id = ?", noteID];
}

- (MBNote *) noteWithID:(NSNumber *)noteID
{
	FMResultSet* results = [self executeQuery:@"SELECT * FROM notes WHERE id = ?", noteID];
	MBNote* note = nil;
	if ([results next]) {
		note = [self noteFromResultSet:results];
	}
	[results close];

	return note;
}

- (NSArray *) notesWithNotebookID:(NSNumber *)notebookID
{
	NSMutableArray* notes = [NSMutableArray array];
	FMResultSet* results = [self executeQuery:@"SELECT * FROM notes WHERE notebook_id = ? ORDER BY updated_at DESC", notebookID];

	while ([results next]) {
		[notes addObject:[self noteFromResultSet:results]];
	}
	[results close];

	return notes;
}

- (id) dbValue:(id)value
{
	return value ?: [NSNull null];
}

- (NSNumber *) timestampFromDate:(NSDate *)date
{
	if (date == nil) {
		return nil;
	}

	return @([date timeIntervalSince1970]);
}

- (NSDate *) dateFromRecordValue:(id)value
{
	if ((value == nil) || (value == [NSNull null])) {
		return nil;
	}

	return [self dateFromTimestamp:[value doubleValue]];
}

- (NSDate *) dateFromTimestamp:(NSTimeInterval)timestamp
{
	if (timestamp == 0) {
		return nil;
	}

	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

@end

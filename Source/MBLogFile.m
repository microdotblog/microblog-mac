//
//  MBLogFile.m
//  Micro.blog
//

#import "MBLogFile.h"

#import "RFAccount.h"

static NSTimeInterval const kLogFileMaximumAge = 5 * 24 * 60 * 60;

@implementation MBLogFile

+ (void) logText:(NSString *)text toName:(NSString *)name
{
	if (name.length == 0) {
		return;
	}

	@synchronized (self) {
		[self cleanupOldLogs];

		NSString* logs_folder = [RFAccount logsFolder];
		NSString* filename = [NSString stringWithFormat:@"%@-%@.txt", [self safeLogName:name], [self dateStringForDate:[NSDate date]]];
		NSString* path = [logs_folder stringByAppendingPathComponent:filename];
		NSString* line = text ?: @"";
		if (![line hasSuffix:@"\n"]) {
			line = [line stringByAppendingString:@"\n"];
		}

		NSData* data = [line dataUsingEncoding:NSUTF8StringEncoding];
		if (data == nil) {
			return;
		}

		NSFileManager* fm = [NSFileManager defaultManager];
		if (![fm fileExistsAtPath:path]) {
			[fm createFileAtPath:path contents:nil attributes:nil];
		}

		NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:path];
		if (handle == nil) {
			return;
		}

		[handle seekToEndOfFile];
		[handle writeData:data];
		[handle closeFile];
	}
}

+ (void) logFields:(NSArray *)fields toName:(NSString *)name
{
	NSMutableArray* cleaned_fields = [NSMutableArray array];
	for (NSString* field in fields) {
		[cleaned_fields addObject:[self singleLineString:field]];
	}

	[self logText:[cleaned_fields componentsJoinedByString:@"\t"] toName:name];
}

+ (NSString *) singleLineString:(NSString *)s
{
	NSString* result = s ?: @"";
	result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
	result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	result = [result stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
	return result;
}

+ (NSString *) dateStringForDate:(NSDate *)date
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	formatter.dateFormat = @"yyyy-MM-dd";
	return [formatter stringFromDate:date];
}

+ (NSString *) safeLogName:(NSString *)name
{
	NSMutableCharacterSet* allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	[allowed addCharactersInString:@".-_"];
	NSArray* parts = [name componentsSeparatedByCharactersInSet:[allowed invertedSet]];
	NSString* safe_name = [parts componentsJoinedByString:@"-"];
	if (safe_name.length == 0) {
		safe_name = @"Log";
	}

	return safe_name;
}

+ (void) cleanupOldLogs
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSURL* logs_url = [NSURL fileURLWithPath:[RFAccount logsFolder] isDirectory:YES];
	NSArray* resource_keys = @[ NSURLContentModificationDateKey, NSURLIsDirectoryKey ];
	NSArray* urls = [fm contentsOfDirectoryAtURL:logs_url includingPropertiesForKeys:resource_keys options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
	NSDate* cutoff_date = [NSDate dateWithTimeIntervalSinceNow:-kLogFileMaximumAge];

	for (NSURL* url in urls) {
		NSDate* modified_date = nil;
		[url getResourceValue:&modified_date forKey:NSURLContentModificationDateKey error:NULL];
		if (modified_date == nil || [modified_date compare:cutoff_date] != NSOrderedAscending) {
			continue;
		}

		if ([self isSafeLogFileToDelete:url]) {
			[fm removeItemAtURL:url error:NULL];
		}
	}
}

+ (BOOL) isSafeLogFileToDelete:(NSURL *)url
{
	if (![[url pathExtension] isEqualToString:@"txt"]) {
		return NO;
	}

	BOOL is_directory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&is_directory] || is_directory) {
		return NO;
	}

	NSString* path = [[url.path stringByResolvingSymlinksInPath] stringByStandardizingPath];
	NSString* logs_folder = [[[RFAccount logsFolder] stringByResolvingSymlinksInPath] stringByStandardizingPath];

	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [[[paths firstObject] stringByResolvingSymlinksInPath] stringByStandardizingPath];

	NSString* logs_prefix = [logs_folder stringByAppendingString:@"/"];
	NSString* support_prefix = [support_folder stringByAppendingString:@"/"];

	return [path hasPrefix:logs_prefix] && [path hasPrefix:support_prefix];
}

@end

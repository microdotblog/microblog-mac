//
//  MBBackupsController.m
//  Micro.blog
//

#import "MBBackupsController.h"

#import "RFAccount.h"
#import "RFBarExportController.h"
#import "RFConstants.h"
#import "RFSettings.h"

static NSTimeInterval const kBackupTimerInterval = 60 * 60; // 1 hour

@interface MBBackupsController ()

@property (strong, nonatomic, nullable) NSTimer* backupTimer;
@property (strong, nonatomic, nullable) RFBarExportController* exportController;
@property (assign, nonatomic) BOOL isRunningBackup;

@end

@implementation MBBackupsController

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) start
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBackupInProgressPrefKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBackupProgressStartingPrefKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kBackupStatusTextPrefKey];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsDidChangeNotification:) name:NSUserDefaultsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelBackupNotification:) name:kCancelBackupNotification object:nil];

	[self updateTimer];
}

- (void) userDefaultsDidChangeNotification:(NSNotification *)notification
{
	[self updateTimer];
}

- (void) cancelBackupNotification:(NSNotification *)notification
{
	[self cancelBackup];
}

- (void) updateTimer
{
	BOOL is_enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kSaveBackupsToFolderPrefKey];
	if (is_enabled && (self.backupTimer == nil)) {
		self.backupTimer = [NSTimer scheduledTimerWithTimeInterval:kBackupTimerInterval target:self selector:@selector(checkForBackup:) userInfo:nil repeats:YES];
		self.backupTimer.tolerance = 60;

		if (![self hasLastBackupDate]) {
			self.backupTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:kInitialBackupTimerInterval];
		}
	}
	else if (!is_enabled && self.backupTimer) {
		[self.backupTimer invalidate];
		self.backupTimer = nil;
	}
}

- (BOOL) hasLastBackupDate
{
	NSDate* last_backup = [[NSUserDefaults standardUserDefaults] objectForKey:kLastBackupDatePrefKey];
	return [last_backup isKindOfClass:[NSDate class]];
}

- (void) checkForBackup:(id)sender
{
	if (self.isRunningBackup) {
		return;
	}

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:kSaveBackupsToFolderPrefKey]) {
		return;
	}

	NSDate* last_backup = [defaults objectForKey:kLastBackupDatePrefKey];
	if (![last_backup isKindOfClass:[NSDate class]] || [[NSDate date] timeIntervalSinceDate:last_backup] > (kBackupMinimumDays * 24 * 60 * 60)) {
		[self runBackup];
	}
}

- (void) runBackup
{
	self.isRunningBackup = YES;
	[self setBackupInProgress:YES];
	[self setBackupProgressStarting:YES];
	[self updateBackupStatus:@"Starting backup..."];

	NSString* path = [self backupPath];
	self.exportController = [[RFBarExportController alloc] init];
	__weak MBBackupsController* weak_self = self;
	[self.exportController exportToPath:path progress:^(double progress) {
		[weak_self setBackupProgressStarting:NO];
		[weak_self postProgress:@(progress)];
	} status:^(NSString* status) {
		[weak_self updateBackupStatus:status];
	} completion:^(BOOL success, NSString* saved_path) {
		MBBackupsController* strong_self = weak_self;
		if (success) {
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastBackupDatePrefKey];
			[strong_self cleanupOldBackups];
		}
		[strong_self setBackupProgressStarting:NO];
		if (success) {
			[strong_self postProgress:@(1.0)];
		}
		else {
			[strong_self postProgress:nil];
		}
		[strong_self updateBackupStatus:nil];
		[strong_self setBackupInProgress:NO];
		strong_self.isRunningBackup = NO;
		strong_self.exportController = nil;
	}];
}

- (void) cancelBackup
{
	if (!self.isRunningBackup) {
		return;
	}

	[self.exportController cancelExport];
	[self setBackupProgressStarting:NO];
	[self updateBackupStatus:nil];
	[self setBackupInProgress:NO];
	[self postProgress:nil];
}

- (void) setBackupInProgress:(BOOL)isInProgress
{
	[[NSUserDefaults standardUserDefaults] setBool:isInProgress forKey:kBackupInProgressPrefKey];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kBackupDidUpdateNotification object:self];
	});
}

- (void) setBackupProgressStarting:(BOOL)isStarting
{
	[[NSUserDefaults standardUserDefaults] setBool:isStarting forKey:kBackupProgressStartingPrefKey];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kBackupDidUpdateNotification object:self];
	});
}

- (void) updateBackupStatus:(NSString *)status
{
	NSDictionary* user_info = nil;
	if (status.length > 0) {
		[[NSUserDefaults standardUserDefaults] setObject:status forKey:kBackupStatusTextPrefKey];
		user_info = @{ kCurrentBackupStatusKey: status };
	}
	else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kBackupStatusTextPrefKey];
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kBackupDidUpdateNotification object:self userInfo:user_info];
	});
}

- (NSString *) backupPath
{
	NSString* backups_folder = [RFAccount backupsFolder];
	NSString* filename = [self backupFilename];
	return [backups_folder stringByAppendingPathComponent:filename];
}

- (NSString *) backupFilename
{
	NSString* safe_blog = [self safeBackupBlogName];
	
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	formatter.dateFormat = @"yyyy-MM-dd";
	NSString* date_s = [formatter stringFromDate:[NSDate date]];
	
	return [NSString stringWithFormat:@"%@-%@.bar", safe_blog, date_s];
}

- (NSString *) safeBackupBlogName
{
	NSString* blog = [RFSettings stringForKey:kCurrentDestinationName];
	if (blog.length == 0) {
		blog = [RFSettings stringForKey:kAccountDefaultSite];
	}
	if (blog.length == 0) {
		blog = @"Micro.blog";
	}

	NSMutableCharacterSet* allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	[allowed addCharactersInString:@".-_"];
	NSArray* parts = [blog componentsSeparatedByCharactersInSet:[allowed invertedSet]];
	NSString* safe_blog = [parts componentsJoinedByString:@"-"];
	if (safe_blog.length == 0) {
		safe_blog = @"Micro.blog";
	}
	
	return safe_blog;
}

- (void) postProgress:(NSNumber *)progress
{
	NSMutableDictionary* user_info = [NSMutableDictionary dictionary];
	if (progress) {
		NSNumber* progress_num = @(MAX(0.0, MIN(1.0, progress.doubleValue)));
		[user_info setObject:progress_num forKey:kCurrentBackupProgressKey];
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kBackupDidUpdateNotification object:self userInfo:user_info];
	});
}

- (void) cleanupOldBackups
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSURL* backups_url = [NSURL fileURLWithPath:[RFAccount backupsFolder] isDirectory:YES];
	NSArray* resource_keys = @[ NSURLContentModificationDateKey, NSURLIsDirectoryKey ];
	NSArray<NSURL *>* urls = [fm contentsOfDirectoryAtURL:backups_url includingPropertiesForKeys:resource_keys options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
	NSString* backup_prefix = [[self safeBackupBlogName] stringByAppendingString:@"-"];

	NSMutableArray<NSDictionary *>* backup_files = [NSMutableArray array];
	for (NSURL* url in urls) {
		if (![[url pathExtension] isEqualToString:@"bar"]) {
			continue;
		}
		if (![url.lastPathComponent hasPrefix:backup_prefix]) {
			continue;
		}

		NSNumber* is_directory = nil;
		[url getResourceValue:&is_directory forKey:NSURLIsDirectoryKey error:NULL];
		if (is_directory.boolValue) {
			continue;
		}

		NSDate* modified_date = nil;
		[url getResourceValue:&modified_date forKey:NSURLContentModificationDateKey error:NULL];
		if (modified_date == nil) {
			modified_date = [NSDate distantPast];
		}

		[backup_files addObject:@{
			@"url": url,
			@"modified_date": modified_date
		}];
	}

	[backup_files sortUsingComparator:^NSComparisonResult(NSDictionary* first, NSDictionary* second) {
		NSDate* first_date = [first objectForKey:@"modified_date"];
		NSDate* second_date = [second objectForKey:@"modified_date"];
		return [second_date compare:first_date];
	}];

	NSInteger backups_to_keep = [[NSUserDefaults standardUserDefaults] integerForKey:kBackupsToKeepPrefKey];
	if (backups_to_keep < 1) {
		backups_to_keep = kDefaultBackupsToKeep;
	}
	for (NSInteger i = backups_to_keep; i < backup_files.count; i++) {
		NSURL* url = [[backup_files objectAtIndex:i] objectForKey:@"url"];
		if ([self isSafeBackupFileToDelete:url]) {
			[fm removeItemAtURL:url error:NULL];
		}
	}
}

- (BOOL) isSafeBackupFileToDelete:(NSURL *)url
{
	if (![[url pathExtension] isEqualToString:@"bar"]) {
		return NO;
	}

	BOOL is_directory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&is_directory] || is_directory) {
		return NO;
	}

	NSString* path = [[url.path stringByResolvingSymlinksInPath] stringByStandardizingPath];
	NSString* backups_folder = [[[RFAccount backupsFolder] stringByResolvingSymlinksInPath] stringByStandardizingPath];

	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [[[paths firstObject] stringByResolvingSymlinksInPath] stringByStandardizingPath];

	NSString* backups_prefix = [backups_folder stringByAppendingString:@"/"];
	NSString* support_prefix = [support_folder stringByAppendingString:@"/"];

	return [path hasPrefix:backups_prefix] && [path hasPrefix:support_prefix];
}

@end

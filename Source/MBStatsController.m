//
//  MBStatsController.m
//  Micro.blog
//

#import "MBStatsController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "SAMKeychain.h"

#import <sys/utsname.h>

static NSString* const kStatsPath = @"/account/stats";
static NSString* const kStatsInstallIDPrefKey = @"StatsInstallID";

@interface MBStatsController ()

- (void) sendStatsOnMainThread;
- (NSDictionary *) statsDictionary;

@end

@implementation MBStatsController

- (void) sendStats
{
	if ([NSThread isMainThread]) {
		[self sendStatsOnMainThread];
	}
	else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self sendStatsOnMainThread];
		});
	}
}

- (void) sendStatsOnMainThread
{
	if (![self hasAccountToken]) {
		return;
	}

	NSDictionary* stats = [self statsDictionary];
	RFClient* client = [[RFClient alloc] initWithPath:kStatsPath];
	[client postWithObject:stats completion:^(UUHttpResponse* response) {
	}];
}

- (BOOL) hasAccountToken
{
	NSString* username = [RFSettings stringForKey:kAccountUsername];
	if (username.length == 0) {
		return NO;
	}

	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];
	return (token.length > 0);
}

- (NSDictionary *) statsDictionary
{
	NSProcessInfo* process_info = [NSProcessInfo processInfo];
	unsigned long long memory_bytes = process_info.physicalMemory;
	double memory_gb = (double)memory_bytes / (1024.0 * 1024.0 * 1024.0);

	return @{
		@"app_version": [self appVersion],
		@"app_build": [self appBuild],
		@"macos_version": [self macOSVersion],
		@"cpu_architecture": [self cpuArchitecture],
		@"memory_bytes": @(memory_bytes),
		@"memory_gb": @(memory_gb),
		@"install_id": [self installID]
	};
}

- (NSString *) appVersion
{
	NSString* version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if (version.length == 0) {
		version = @"unknown";
	}

	return version;
}

- (NSString *) appBuild
{
	NSString* build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	if (build.length == 0) {
		build = @"unknown";
	}

	return build;
}

- (NSString *) macOSVersion
{
	NSOperatingSystemVersion os_version = [[NSProcessInfo processInfo] operatingSystemVersion];
	if (os_version.patchVersion > 0) {
		return [NSString stringWithFormat:@"%ld.%ld.%ld", os_version.majorVersion, os_version.minorVersion, os_version.patchVersion];
	}
	else {
		return [NSString stringWithFormat:@"%ld.%ld", os_version.majorVersion, os_version.minorVersion];
	}
}

- (NSString *) cpuArchitecture
{
	struct utsname system_info;
	if (uname(&system_info) != 0) {
		return @"unknown";
	}

	return [NSString stringWithUTF8String:system_info.machine];
}

- (NSString *) installID
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* install_id = [defaults stringForKey:kStatsInstallIDPrefKey];
	if (install_id.length == 0) {
		install_id = [[NSUUID UUID] UUIDString];
	}

	install_id = [install_id stringByReplacingOccurrencesOfString:@"-" withString:@""];
	if (![[defaults stringForKey:kStatsInstallIDPrefKey] isEqualToString:install_id]) {
		[defaults setObject:install_id forKey:kStatsInstallIDPrefKey];
	}

	return install_id;
}

@end

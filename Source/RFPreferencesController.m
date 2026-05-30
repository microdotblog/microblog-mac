//
//  RFPreferencesController.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPreferencesController.h"

#import "RFConstants.h"
#import "RFAccount.h"
#import "RFAccountCell.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "RFXMLLinkParser.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "RFWordpressController.h"
#import "MBRobotsController.h"
#import "MBRobotsModel.h"
#import "NSString+Extras.h"
#import "UUHttpSession.h"
#import "UUString.h"
#import "SAMKeychain.h"
#import "NSAlert+Extras.h"
#import <CoreImage/CoreImage.h>

static CGFloat const kWordPressMenusHeight = 100;
static CGFloat const kDayOneSettingsPadding = 15;
static CGFloat const kToolbarHeight = 82;
static NSString* const kAccountCellIdentifier = @"AccountCell";

@interface RFPreferencesController ()

@property (strong, nonatomic) MBRobotsController* robotsController;
@property (assign, nonatomic) BOOL isRobotsMachineSupported;

@end

@implementation RFPreferencesController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Preferences"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupToolbar];
	[self setupAccounts];
	[self setupTextPopup];
	[self setupNotifications];
	[self setupCollectionView];
	[self selectFirstAccount];
	
	[self setupWebsiteField];
	[self setupDayOneField];
	[self setupNotesCheckboxes];
	[self setupBackupCheckboxes];
	[self setupBackupRecentsPopup];
	[self setupBackupProgressBar];
	[self setupRobotsSettings];

	[self updateRadioButtons];
	[self updateMenus];

	[self hideMessage];
	[self hideWordPressMenus];
	
	[self showGeneralPane:nil];
}

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self loadCategories];
	if (self.hasShownWindow) {
		[self refreshAccounts];
	}
	else {
		self.hasShownWindow = YES;
	}
}

- (void) removeAccountNotification:(NSNotification *)notification
{
	RFAccount* a = self.selectedAccount;
	
	NSAlert* sheet = [[NSAlert alloc] init];
	sheet.messageText = [NSString stringWithFormat:@"Remove @%@?", a.username];
	sheet.informativeText = @"This account will be removed from the application. You can add it back later by clicking \"+\".";
	[sheet addButtonWithTitle:@"Remove"];
	[sheet addButtonWithTitle:@"Cancel"];
	[sheet beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == 1000) {
			[RFSettings removeAccount:a];
			[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshAccountsNotification object:self];
		}
	}];
}

- (void) refreshAccountsNotification:(NSNotification *)notification
{
	[self refreshAccounts];
}

- (void) setupToolbar
{
	[self.toolbar setSelectedItemIdentifier:@"General"];
}

- (void) setupAccounts
{
	self.accounts = [RFSettings accounts];
	
	RFAccount* blank_a = [[RFAccount alloc] init];
	blank_a.username = @"";
	self.accounts = [self.accounts arrayByAddingObject:blank_a];
}

- (void) setupWebsiteField
{
	self.websiteReturnButton.alphaValue = 0.0;
	self.websiteField.delegate = self;
	
	NSString* s = [RFSettings stringForKey:kExternalBlogURL account:self.selectedAccount];
	if (s) {
		self.websiteField.stringValue = s;
	}
	else {
		self.websiteField.stringValue = @"";
	}
}

- (void) setupTextPopup
{
	for (NSMenuItem* item in self.textSizePopup.menu.itemArray) {
		if ([item.title isEqualToString:@"Tiny"]) {
			item.tag = kTextSizeTiny;
		}
		else if ([item.title isEqualToString:@"Small"]) {
			item.tag = kTextSizeSmall;
		}
		else if ([item.title isEqualToString:@"Medium"]) {
			item.tag = kTextSizeMedium;
		}
		else if ([item.title isEqualToString:@"Large"]) {
			item.tag = kTextSizeLarge;
		}
		else if ([item.title isEqualToString:@"Huge"]) {
			item.tag = kTextSizeHuge;
		}
	}

	NSInteger text_size = [[NSUserDefaults standardUserDefaults] integerForKey:kTextSizePrefKey];
	[self.textSizePopup selectItemWithTag:text_size];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.window];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAccountNotification:) name:kRemoveAccountNotification object:self.accountsCollectionView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountsNotification:) name:kRefreshAccountsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backupDidUpdateNotification:) name:kBackupDidUpdateNotification object:nil];
}

- (void) setupBackupProgressBar
{
	self.backupProgressBar.hidden = YES;
	self.backupProgressBar.indeterminate = NO;
	self.backupProgressBar.minValue = 0.0;
	self.backupProgressBar.maxValue = 1.0;
	self.backupProgressBar.doubleValue = 0.0;
	self.backupStatusField.hidden = YES;
	self.backupCancelButton.hidden = YES;
}

- (void) setupRobotsSettings
{
	self.robotsController = [[MBRobotsController alloc] init];
	self.isRobotsMachineSupported = [MBRobotsController isSupportedMachine];

	self.robotsStatusField.stringValue = self.isRobotsMachineSupported ? @"Requires: 15 GB storage" : @"Requires: M1 or later and 24 GB of memory";
	self.robotsCheckbox.enabled = self.isRobotsMachineSupported;

	BOOL is_enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kUseLocalAIModelsPrefKey];
	if (!self.isRobotsMachineSupported || (is_enabled && ![MBRobotsModel isLocalModelAvailable])) {
		is_enabled = NO;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kUseLocalAIModelsPrefKey];
	}

	self.robotsCheckbox.state = is_enabled ? NSControlStateValueOn : NSControlStateValueOff;
	[self hideRobotsDownloadProgress];
}

- (void) setupBackupRecentsPopup
{
	for (NSMenuItem* item in self.backupRecentsPopup.menu.itemArray) {
		item.tag = item.title.integerValue;
	}
	
	NSInteger backups_to_keep = [[NSUserDefaults standardUserDefaults] integerForKey:kBackupsToKeepPrefKey];
	if (backups_to_keep < 1) {
		backups_to_keep = kDefaultBackupsToKeep;
	}
	[self.backupRecentsPopup selectItemWithTag:backups_to_keep];
}

- (void) updateBackupRecentsEnabled
{
	BOOL is_enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kSaveBackupsToFolderPrefKey];
	self.backupRecentsField.enabled = is_enabled;
	self.backupRecentsPopup.enabled = is_enabled;
}

- (NSString *) localizedBackupDateString:(NSDate *)date
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = NSDateFormatterShortStyle;
	formatter.timeStyle = NSDateFormatterShortStyle;
	return [formatter stringFromDate:date];
}

- (void) updateBackupDateField
{
	NSDate* last_backup = [[NSUserDefaults standardUserDefaults] objectForKey:kLastBackupDatePrefKey];
	if ([last_backup isKindOfClass:[NSDate class]]) {
		self.backupDateField.stringValue = [NSString stringWithFormat:@"Last backup: %@", [self localizedBackupDateString:last_backup]];
	}
	else {
		NSDate* next_backup = [NSDate dateWithTimeIntervalSinceNow:kInitialBackupTimerInterval];
		self.backupDateField.stringValue = [NSString stringWithFormat:@"Next backup: %@", [self localizedBackupDateString:next_backup]];
	}
}

- (void) updateBackupStatus:(NSString *)status
{
	BOOL is_in_progress = [[NSUserDefaults standardUserDefaults] boolForKey:kBackupInProgressPrefKey];
	NSString* current_status = status;
	if (current_status.length == 0) {
		current_status = [[NSUserDefaults standardUserDefaults] stringForKey:kBackupStatusTextPrefKey];
	}
	if (current_status.length == 0) {
		current_status = @"Starting backup...";
	}

	self.backupStatusField.hidden = !is_in_progress;
	self.backupCancelButton.hidden = !is_in_progress;
	if (is_in_progress) {
		self.backupStatusField.stringValue = current_status;
	}
}

- (void) updateBackupProgressBarWithProgress:(NSNumber *)progress status:(NSString *)status
{
	BOOL is_in_progress = [[NSUserDefaults standardUserDefaults] boolForKey:kBackupInProgressPrefKey];
	[self updateBackupStatus:status];

	if (!is_in_progress) {
		self.backupProgressBar.hidden = YES;
		self.backupProgressBar.doubleValue = 0.0;
		return;
	}

	BOOL is_starting = [[NSUserDefaults standardUserDefaults] boolForKey:kBackupProgressStartingPrefKey];
	if (is_starting) {
		self.backupProgressBar.hidden = NO;
		self.backupProgressBar.indeterminate = YES;
		[self.backupProgressBar startAnimation:nil];
		return;
	}

	self.backupProgressBar.indeterminate = NO;
	[self.backupProgressBar stopAnimation:nil];

	if (progress == nil) {
		return;
	}

	self.backupProgressBar.hidden = NO;
	self.backupProgressBar.doubleValue = progress.doubleValue;

	if (progress.doubleValue >= 1.0) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			self.backupProgressBar.hidden = YES;
			self.backupProgressBar.doubleValue = 0.0;
			self.backupStatusField.hidden = YES;
			self.backupCancelButton.hidden = YES;
		});
	}
}

- (void) setupCollectionView
{
	self.accountsCollectionView.delegate = self;
	self.accountsCollectionView.dataSource = self;
	
	[self.accountsCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"AccountCell" bundle:nil] forItemWithIdentifier:kAccountCellIdentifier];
}

- (void) setupBackupCheckboxes
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults boolForKey:kSaveBackupsToFolderPrefKey]) {
		[self.backupFolderCheckbox setState:NSControlStateValueOn];
	}
	else {
		[self.backupFolderCheckbox setState:NSControlStateValueOff];
	}
	
	[self updateBackupRecentsEnabled];
}

- (void) setupNotesCheckboxes
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults boolForKey:kSaveNotesToFolderPrefKey]) {
		[self.notesFolderCheckbox setState:NSControlStateValueOn];
	}
	else {
		[self.notesFolderCheckbox setState:NSControlStateValueOff];
	}
	
	if ([defaults boolForKey:kSaveKeyToCloudPrefKey]) {
		[self.notesCloudCheckbox setState:NSControlStateValueOn];
	}
	else {
		[self.notesCloudCheckbox setState:NSControlStateValueOff];
	}
}

- (void) loadCategories
{
	NSString* xmlrpc_endpoint = [RFSettings stringForKey:kExternalBlogEndpoint account:self.selectedAccount];
	if (xmlrpc_endpoint) {
		[self.websiteProgressSpinner startAnimation:nil];

		NSString* blog_s = [RFSettings stringForKey:kExternalBlogID account:self.selectedAccount];
		NSString* username = [RFSettings stringForKey:kExternalBlogUsername account:self.selectedAccount];
		NSString* password = [SAMKeychain passwordForService:@"ExternalBlog" account:username];
		
		if (!blog_s || !username || !password) {
			return;
		}
		
		NSNumber* blog_id = [NSNumber numberWithInteger:[blog_s integerValue]];
		NSString* taxonomy = @"category";
		
		NSArray* params = @[ blog_id, username, password, taxonomy ];
		
		RFXMLRPCRequest* request = [[RFXMLRPCRequest alloc] initWithURL:xmlrpc_endpoint];
		[request sendMethod:@"wp.getTerms" params:params completion:^(UUHttpResponse* response) {
			RFXMLRPCParser* xmlrpc = [RFXMLRPCParser parsedResponseFromData:response.rawResponse];

			NSMutableArray* new_categories = [NSMutableArray array];
			NSMutableArray* new_ids = [NSMutableArray array];
			for (NSDictionary* cat_info in xmlrpc.responseParams.firstObject) {
				[new_categories addObject:cat_info[@"name"]];
				[new_ids addObject:cat_info[@"term_id"]];
			}

			RFDispatchMainAsync (^{
				[self.categoryPopup removeAllItems];
				
				for (NSInteger i = 0; i < new_ids.count; i++) {
					NSString* cat_title = new_categories[i];
					NSNumber* cat_id = new_ids[i];
					NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:cat_title action:NULL keyEquivalent:@""];
					item.tag = cat_id.integerValue;
					[self.categoryPopup.menu addItem:item];
				}
				
				self.hasLoadedCategories = YES;
				[self updateMenus];
				[self.websiteProgressSpinner stopAnimation:nil];
			});
		}];
	}
}

- (void) selectFirstAccount
{
	NSSet* first_item = [NSSet setWithObject:[NSIndexPath indexPathForItem:0 inSection:0]];
	[self.accountsCollectionView selectItemsAtIndexPaths:first_item scrollPosition:NSCollectionViewScrollPositionNone];
	RFAccount* a = [self.accounts firstObject];
	[self showSettingsForAccount:a];
}

- (void) refreshAccounts
{
	[self setupAccounts];
	[self.accountsCollectionView reloadData];
	[self selectFirstAccount];

	RFDispatchSeconds (0.5, ^{
		// delay slightly to give message pane time to potentially finish
		[self showMenusIfWordPress];
	});
}

- (void) showSettingsForAccount:(RFAccount *)account
{
	self.selectedAccount = account;
	
	[self setupWebsiteField];
    [self setupDayOneField];
	[self updateRadioButtons];
	[self updateMenus];

	RFDispatchSeconds (0.5, ^{
		// delay slightly to give message pane time to potentially finish
		[self showMenusIfWordPress];
	});
}

- (void) promptNewAccount
{
	NSString* url = @"https://micro.blog/account/mac";
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

#pragma mark -

- (IBAction) setHostedBlog:(id)sender
{
	[RFSettings setBool:NO forKey:kExternalBlogIsPreferred account:self.selectedAccount];
	[self updateRadioButtons];
	[self showMenusIfWordPress];
}

- (IBAction) setWordPressBlog:(id)sender
{
	[RFSettings setBool:YES forKey:kExternalBlogIsPreferred account:self.selectedAccount];
	[self updateRadioButtons];
	[self showMenusIfWordPress];
}

- (IBAction) websiteReturnButtonPressed:(id)sender
{
	[self hideWebsiteReturnButton];
	[self checkWebsite];
}

- (IBAction) postFormatChanged:(NSPopUpButton *)sender
{
	NSString* s = [[sender selectedItem] title];
	[RFSettings setString:s forKey:kExternalBlogFormat account:self.selectedAccount];
}

- (IBAction) categoryChanged:(NSPopUpButton *)sender
{
	NSInteger tag = [[sender selectedItem] tag];
	NSString* s = [NSString stringWithFormat:@"%ld", (long)tag];
	[RFSettings setString:s forKey:kExternalBlogCategory account:self.selectedAccount];
}

- (void) controlTextDidChange:(NSNotification *)notification
{
    if ([notification.object isEqual:self.websiteField]) {
        NSString* s = self.websiteField.stringValue;
        if (s.length > 0) {
            [self showWebsiteReturnButton];
        }
        else {
            [self hideWebsiteReturnButton];
        }
    }
    else if ([notification.object isEqual:self.dayOneJournalNameField]) {
        [self dayOneTextDidChange];
    }
}

- (IBAction) websiteTextChanged:(NSTextField *)sender
{
	[self hideWebsiteReturnButton];
	if (sender.stringValue.length > 0) {
		[self checkWebsite];
	}
}

- (IBAction) textSizeChanged:(NSPopUpButton *)sender
{
	NSInteger tag = [[sender selectedItem] tag];
	[[NSUserDefaults standardUserDefaults] setInteger:tag forKey:kTextSizePrefKey];

	NSString* username = [RFSettings stringForKey:kAccountUsername];
	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&fontsize=%ld", token, (long)tag];
	[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshTimelineNotification object:self];
		});
	}];
}

- (IBAction) showGeneralPane:(id)sender
{
	self.notesPane.hidden = YES;
	self.backupPane.hidden = YES;
	self.robotsPane.hidden = YES;
	[self.window.contentView addSubview:self.generalPane];
	[self.generalPane setFrameOrigin:NSMakePoint(0, 0)];
	self.generalPane.hidden = NO;
}

- (IBAction) showNotesPane:(id)sender
{
	self.generalPane.hidden = YES;
	self.backupPane.hidden = YES;
	self.robotsPane.hidden = YES;
	[self.window.contentView addSubview:self.notesPane];
	[self.notesPane setFrameOrigin:NSMakePoint(0, 0)];
	self.notesPane.hidden = NO;
}

- (IBAction) showBackupPane:(id)sender
{
	self.generalPane.hidden = YES;
	self.notesPane.hidden = YES;
	self.robotsPane.hidden = YES;
	[self.window.contentView addSubview:self.backupPane];
	[self.backupPane setFrameOrigin:NSMakePoint(0, 0)];
	self.backupPane.hidden = NO;
	[self updateBackupRecentsEnabled];
	[self updateBackupDateField];
	[self updateBackupProgressBarWithProgress:nil status:nil];
}

- (IBAction) showRobotsPane:(id)sender
{
	self.generalPane.hidden = YES;
	self.notesPane.hidden = YES;
	self.backupPane.hidden = YES;
	[self.window.contentView addSubview:self.robotsPane];
	[self.robotsPane setFrameOrigin:NSMakePoint(0, 0)];
	self.robotsPane.hidden = NO;
	[self updateRobotsSettings];
}

- (IBAction) folderCheckboxChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSControlStateValueOn) forKey:kSaveNotesToFolderPrefKey];
}

- (IBAction) cloudCheckboxChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSControlStateValueOn) forKey:kSaveKeyToCloudPrefKey];
}

- (IBAction) showNotesFolder:(id)sender
{
	NSString* notes_folder = [RFAccount notesFolder];
	NSURL* url = [NSURL fileURLWithPath:notes_folder];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ url ]];
}

- (IBAction) showBackupsFolder:(id)sender
{
	NSString* notes_folder = [RFAccount backupsFolder];
	NSURL* url = [NSURL fileURLWithPath:notes_folder];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ url ]];
}

- (IBAction) backupsFolderCheckboxChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSControlStateValueOn) forKey:kSaveBackupsToFolderPrefKey];
	[self updateBackupRecentsEnabled];
}

- (IBAction) backupsRecentsChanged:(id)sender
{
	NSInteger backups_to_keep = [[sender selectedItem] tag];
	[[NSUserDefaults standardUserDefaults] setInteger:backups_to_keep forKey:kBackupsToKeepPrefKey];
}

- (IBAction) cancelBackup:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kCancelBackupNotification object:self];
}

- (IBAction) aiCheckboxChecked:(id)sender
{
	if (self.robotsCheckbox.state == NSControlStateValueOn) {
		[self enableLocalRobotsModel];
	}
	else {
		[self disableLocalRobotsModel];
	}
}

- (void) updateRobotsSettings
{
	self.isRobotsMachineSupported = [MBRobotsController isSupportedMachine];
	self.robotsStatusField.stringValue = self.isRobotsMachineSupported ? @"Requires: 15 GB storage" : @"Requires: M1 or later and 24 GB of memory";
	self.robotsCheckbox.enabled = self.isRobotsMachineSupported;

	if (!self.isRobotsMachineSupported) {
		self.robotsCheckbox.state = NSControlStateValueOff;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kUseLocalAIModelsPrefKey];
		[self hideRobotsDownloadProgress];
	}
}

- (void) enableLocalRobotsModel
{
	if (!self.isRobotsMachineSupported) {
		self.robotsCheckbox.state = NSControlStateValueOff;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kUseLocalAIModelsPrefKey];
		return;
	}

	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kUseLocalAIModelsPrefKey];

	if ([MBRobotsModel isLocalModelAvailable]) {
		[self showRobotsDownloadStatus:@"Local model is ready." detail:@""];
		return;
	}

	__weak RFPreferencesController* weak_self = self;
	[self.robotsController startDownloadingModelWithProgress:^(BOOL indeterminate, double progress, NSString* status, NSString* detail) {
		[weak_self updateRobotsDownloadProgressIndeterminate:indeterminate progress:progress status:status detail:detail];
	} completion:^(BOOL success, BOOL cancelled, NSError* error) {
		[weak_self robotsDownloadDidFinishWithSuccess:success cancelled:cancelled error:error];
	}];
}

- (void) disableLocalRobotsModel
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kUseLocalAIModelsPrefKey];

	if (self.robotsController.isDownloading) {
		[self.robotsController cancelDownload];
	}

	[MBRobotsModel deleteLocalModelFiles];
	[self hideRobotsDownloadProgress];
}

- (void) updateRobotsDownloadProgressIndeterminate:(BOOL)indeterminate progress:(double)progress status:(NSString *)status detail:(NSString *)detail
{
	self.downloadModelProgressBar.hidden = NO;
	self.downloadModelStatusField.hidden = NO;
	self.downloadModelRemainingField.hidden = (detail.length == 0);
	self.downloadModelStatusField.stringValue = status ?: @"";
	self.downloadModelRemainingField.stringValue = detail ?: @"";

	self.downloadModelProgressBar.minValue = 0.0;
	self.downloadModelProgressBar.maxValue = 1.0;
	self.downloadModelProgressBar.indeterminate = indeterminate;
	if (indeterminate) {
		[self.downloadModelProgressBar startAnimation:nil];
	}
	else {
		[self.downloadModelProgressBar stopAnimation:nil];
		self.downloadModelProgressBar.doubleValue = MAX(0.0, MIN(1.0, progress));
	}
}

- (void) robotsDownloadDidFinishWithSuccess:(BOOL)success cancelled:(BOOL)cancelled error:(NSError *)error
{
	if (success) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kUseLocalAIModelsPrefKey];
		self.robotsCheckbox.state = NSControlStateValueOn;
		[self updateRobotsDownloadProgressIndeterminate:NO progress:1.0 status:@"Local model is ready." detail:@""];
	}
	else {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kUseLocalAIModelsPrefKey];
		self.robotsCheckbox.state = NSControlStateValueOff;
		if (cancelled) {
			[self hideRobotsDownloadProgress];
		}
		else {
			NSString* error_message = error.localizedDescription ?: @"Download failed.";
			[self showRobotsDownloadStatus:@"Download failed." detail:error_message];
		}
	}
}

- (void) showRobotsDownloadStatus:(NSString *)status detail:(NSString *)detail
{
	self.downloadModelProgressBar.hidden = YES;
	[self.downloadModelProgressBar stopAnimation:nil];
	self.downloadModelStatusField.hidden = NO;
	self.downloadModelRemainingField.hidden = (detail.length == 0);
	self.downloadModelStatusField.stringValue = status ?: @"";
	self.downloadModelRemainingField.stringValue = detail ?: @"";
}

- (void) hideRobotsDownloadProgress
{
	self.downloadModelProgressBar.hidden = YES;
	self.downloadModelProgressBar.indeterminate = NO;
	self.downloadModelProgressBar.doubleValue = 0.0;
	[self.downloadModelProgressBar stopAnimation:nil];
	self.downloadModelStatusField.hidden = YES;
	self.downloadModelRemainingField.hidden = YES;
	self.downloadModelStatusField.stringValue = @"";
	self.downloadModelRemainingField.stringValue = @"";
}

- (void) backupDidUpdateNotification:(NSNotification *)notification
{
	NSNumber* progress = [notification.userInfo objectForKey:kCurrentBackupProgressKey];
	NSString* status = [notification.userInfo objectForKey:kCurrentBackupStatusKey];
	[self updateBackupDateField];
	[self updateBackupProgressBarWithProgress:progress status:status];
}

- (IBAction) showSecretKey:(id)sender
{
	if (self.notesKeyField.hidden) {
		NSString* s = [SAMKeychain passwordForService:@"Micro.blog Notes" account:@""];
		if (s) {
			self.notesKeyField.stringValue = s;
			self.notesKeyField.hidden = NO;

			[self generateQRCode:s];
			self.qrCodeView.hidden = NO;
			self.qrCodeArrow.hidden = NO;
			self.qrCodeInfo.hidden = NO;
			
			[self.showNotesKeyButton setTitle:@"Hide Secret Key"];
		}
	}
	else {
		self.notesKeyField.stringValue = @"";
		self.notesKeyField.hidden = YES;
		self.qrCodeView.hidden = YES;
		self.qrCodeArrow.hidden = YES;
		self.qrCodeInfo.hidden = YES;

		[self.showNotesKeyButton setTitle:@"Show Secret Key"];
	}
}

- (void) generateQRCode:(NSString *)key
{
	NSString* s = [NSString stringWithFormat:@"strata://qrcode/%@", key];
	NSData* d = [s dataUsingEncoding:NSUTF8StringEncoding];

	// QR code generator filter
	CIFilter* filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
	[filter setValue:d forKey:@"inputMessage"];
	[filter setValue:@"H" forKey:@"inputCorrectionLevel"];

	// figure out how to scale this up, 2x for retina
	CIImage* cg_img = filter.outputImage;
	CGFloat scale = (self.qrCodeView.bounds.size.width / cg_img.extent.size.width) * 2.0;
	CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);

	// transform and convert to an NSImage
	CIImage* ci_img = [cg_img imageByApplyingTransform:t];
	NSImage* img = [[NSImage alloc] initWithSize:self.qrCodeView.bounds.size];
	[img addRepresentation:[NSCIImageRep imageRepWithCIImage:ci_img]];

	[self.qrCodeView setImage:img];
}

- (IBAction) saveSecretKey:(id)sender
{
	NSString* s = [SAMKeychain passwordForService:@"Micro.blog Notes" account:@""];
	if (s) {
		NSSavePanel* panel = [NSSavePanel savePanel];
		panel.nameFieldStringValue = @"microblog_notes_key.txt";
		NSModalResponse response = [panel runModal];
		if (response == NSModalResponseOK) {
			[s writeToURL:panel.URL atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

#pragma mark -

- (void) showMessage:(NSString *)message
{
	self.messageField.stringValue = message;
	
	if (self.messageTopConstraint.constant < -1) {
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
			NSRect win_r = self.window.frame;
			win_r.size.height += self.messageHeader.bounds.size.height;
			win_r.origin.y -= self.messageHeader.bounds.size.height;

			context.duration = [self.window animationResizeTime:win_r];
			
			self.messageTopConstraint.animator.constant = -1;
			[self.window.animator setFrame:win_r display:YES];
		} completionHandler:^{
		}];
	}
}

- (void) hideMessage
{
	self.messageTopConstraint.constant = -(self.messageHeader.bounds.size.height);
	
	NSSize win_size = self.window.frame.size;
	win_size.height -= (self.messageHeader.bounds.size.height + kToolbarHeight);
	[self.window setContentSize:win_size];
}

- (void) showMenusIfWordPress
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred account:self.selectedAccount] && [[RFSettings stringForKey:kExternalBlogApp account:self.selectedAccount] isEqualToString:@"WordPress"]) {
		if (!self.isShowingWordPressMenus) {
			[self setWordPressEnabled:YES];
            self.isShowingWordPressMenus = YES;
		}
	}
	else {
		if (self.isShowingWordPressMenus) {
			[self setWordPressEnabled:NO];
            self.isShowingWordPressMenus = NO;
		}
	}
}

- (void) setWordPressEnabled:(BOOL)isEnabled
{
	self.postFormatField.enabled = isEnabled;
	self.postFormatPopup.enabled = isEnabled;
	self.categoryField.enabled = isEnabled;
	self.categoryPopup.enabled = isEnabled;
}

- (void) hideWordPressMenus
{
	[self setWordPressEnabled:NO];
	self.isShowingWordPressMenus = NO;
}

- (void) updateRadioButtons
{
	if (![RFSettings boolForKey:kExternalBlogIsPreferred account:self.selectedAccount]) {
		self.publishHostedBlog.state = NSControlStateValueOn;
		self.publishWordPressBlog.state = NSControlStateValueOff;
		self.websiteField.enabled = NO;
		self.postFormatPopup.enabled = NO;
		self.categoryPopup.enabled = NO;
	}
	else {
		self.publishHostedBlog.state = NSControlStateValueOff;
		self.publishWordPressBlog.state = NSControlStateValueOn;
		self.websiteField.enabled = YES;
		self.postFormatPopup.enabled = YES;
		self.categoryPopup.enabled = YES;
	}
}

-  (void) updateMenus
{
	NSString* selected_format = [RFSettings stringForKey:kExternalBlogFormat account:self.selectedAccount];
	NSString* selected_category = [RFSettings stringForKey:kExternalBlogCategory account:self.selectedAccount];
    NSString* selected_dayOneJournal = [RFSettings stringForKey:kDayOneJournalName account:self.selectedAccount];

	if (self.hasLoadedCategories) {
		if ([RFSettings boolForKey:kExternalBlogIsPreferred account:self.selectedAccount]) {
			self.postFormatPopup.enabled = YES;
			self.categoryPopup.enabled = YES;
		}
	}

	if (selected_format) {
		[self.postFormatPopup selectItemWithTitle:selected_format];
	}
	
	if (selected_category) {
		[self.categoryPopup selectItemWithTag:selected_category.integerValue];
	}

    if (selected_dayOneJournal) {
        [self.dayOneJournalNameField setStringValue:selected_dayOneJournal];
    }
}

- (void) showWebsiteReturnButton
{
	self.websiteReturnButton.animator.alphaValue = 1.0;
}

- (void) hideWebsiteReturnButton
{
	self.websiteReturnButton.animator.alphaValue = 0.0;
}

- (void) checkWebsite
{
	[self.websiteProgressSpinner startAnimation:nil];

	NSString* full_url = [self normalizeURL:self.websiteField.stringValue];
	[RFSettings setString:full_url forKey:kExternalBlogURL account:self.selectedAccount];

	UUHttpRequest* request = [UUHttpRequest getRequest:full_url queryArguments:nil];
	[UUHttpSession executeRequest:request completionHandler:^(UUHttpResponse* response) {
		RFXMLLinkParser* rsd_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"EditURI"];
		if ([rsd_parser.foundURLs count] > 0) {
			NSString* rsd_url = [rsd_parser.foundURLs firstObject];
            RFDispatchMainAsync (^{
				[self.websiteProgressSpinner stopAnimation:nil];

                self.wordpressController = [[RFWordpressController alloc] initWithWebsite:full_url rsdURL:rsd_url];
				[self.window beginSheet:self.wordpressController.window completionHandler:^(NSModalResponse returnCode) {
					if (returnCode == NSModalResponseOK) {
						[self showMessage:@"Weblog settings have been updated."];
					}
                    self.wordpressController = nil;
				}];
            });
		}
		else {
			RFXMLLinkParser* micropub_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"micropub"];
			if ([micropub_parser.foundURLs count] > 0) {
				RFXMLLinkParser* auth_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"authorization_endpoint"];
				RFXMLLinkParser* token_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"token_endpoint"];
				if (([auth_parser.foundURLs count] > 0) && ([token_parser.foundURLs count] > 0)) {
					NSString* auth_endpoint = [auth_parser.foundURLs firstObject];
					NSString* token_endpoint = [token_parser.foundURLs firstObject];
					NSString* micropub_endpoint = [micropub_parser.foundURLs firstObject];
					
					NSString* micropub_state = [[[NSString uuGenerateUUIDString] lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];

					NSMutableString* auth_with_params = [auth_endpoint mutableCopy];
					if (![auth_with_params containsString:@"?"]) {
						[auth_with_params appendString:@"?"];
					}
					[auth_with_params appendFormat:@"me=%@", [full_url rf_urlEncoded]];
					[auth_with_params appendFormat:@"&redirect_uri=%@", [@"https://micro.blog/micropub/redirect" rf_urlEncoded]];
					[auth_with_params appendFormat:@"&client_id=%@", [@"https://micro.blog/" rf_urlEncoded]];
					[auth_with_params appendFormat:@"&state=%@", micropub_state];
					[auth_with_params appendString:@"&scope=create"];
					[auth_with_params appendString:@"&response_type=code"];

					[RFSettings setString:micropub_state forKey:kExternalMicropubState account:self.selectedAccount];
					[RFSettings setString:token_endpoint forKey:kExternalMicropubTokenEndpoint account:self.selectedAccount];
					[RFSettings setString:micropub_endpoint forKey:kExternalMicropubPostingEndpoint account:self.selectedAccount];

					RFDispatchMainAsync (^{
						[self.websiteProgressSpinner stopAnimation:nil];
						[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:auth_with_params]];
					});
				}
			}
			else {
				RFDispatchMainAsync (^{
					[self.websiteProgressSpinner stopAnimation:nil];
					[NSAlert rf_showOneButtonAlert:@"Error Discovering Settings" message:@"Could not find the XML-RPC endpoint or Micropub API for your weblog." button:@"OK" completionHandler:NULL];
				});
			}
		}
	}];
}

- (NSString *) normalizeURL:(NSString *)url
{
	NSString* s = url;
	if (![s containsString:@"http"]) {
		s = [@"http://" stringByAppendingString:s];
	}
	
	return s;
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.accounts.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFAccount* a = [self.accounts objectAtIndex:indexPath.item];
	
	RFAccountCell* item = (RFAccountCell *)[collectionView makeItemWithIdentifier:kAccountCellIdentifier forIndexPath:indexPath];
	[item setupWithAccount:a];

//	NSLog (@"setting up account: %@, self: %@", a.username, [self description]);

	return item;
}

//- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(RFAccountCell *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
//{
//	RFAccount* a = [self.accounts objectAtIndex:indexPath.item];
//	[item setupWithAccount:a loadProfile:YES];
//}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	NSIndexPath* index_path = [indexPaths anyObject];
	if ((index_path.item + 1) == self.accounts.count) {
		[self promptNewAccount];
	}
	else {
		RFAccount* a = [self.accounts objectAtIndex:index_path.item];
		[self showSettingsForAccount:a];
	}
}

#pragma mark -

- (void) setupDayOneField
{
    [self hideDayOneReturnButton];
    self.dayOneJournalNameField.delegate = self;

    NSString* s = [RFSettings stringForKey:kDayOneJournalName account:self.selectedAccount];

    if (s) {
        self.dayOneJournalNameField.stringValue = s;
    }
    else {
        self.dayOneJournalNameField.stringValue = @"";
    }
}

- (void) dayOneTextDidChange
{
    NSString* s = self.dayOneJournalNameField.stringValue;

    if (s.length > 0) {
        [self showDayOneReturnButton];
    }
    else {
        [self hideDayOneReturnButton];
    }
}

- (IBAction) dayOneTextChanged:(NSTextField *)sender
{
    [self saveDayOneJournal];
}

- (IBAction) dayOneJournalReturnClicked:(NSButton *)sender
{
    [self saveDayOneJournal];
}

- (void) showDayOneReturnButton
{
    self.dayOneReturnButton.hidden = NO;
}

- (void) hideDayOneReturnButton
{
    self.dayOneReturnButton.hidden = YES;
}

- (void) saveDayOneJournal
{
    NSString* journalName = self.dayOneJournalNameField.stringValue;
    NSString* alertMessage = @"Day One will import to the default journal (first in list).";

    if (journalName.length > 0) {
        alertMessage = [NSString stringWithFormat:@"Day One will import to \"%@\". Make sure it exists.", journalName];
    }

    [self hideDayOneReturnButton];
    [RFSettings setString:journalName forKey:kDayOneJournalName account:self.selectedAccount];

    RFDispatchMainAsync (^{
		[self showMessage:alertMessage];
//        [NSAlert rf_showOneButtonAlert:@"Day One Journal" message:alertMessage button:@"OK" completionHandler:NULL];
    });
}

@end

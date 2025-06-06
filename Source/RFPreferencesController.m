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
#import "MBLlama.h"
#import "NSString+Extras.h"
#import "UUHttpSession.h"
#import "UUString.h"
#import "SAMKeychain.h"
#import "NSAlert+Extras.h"
#import <CoreImage/CoreImage.h>
#import <sys/sysctl.h>

static CGFloat const kWordPressMenusHeight = 100;
static CGFloat const kDayOneSettingsPadding = 15;
static CGFloat const kToolbarHeight = 82;
static NSString* const kAccountCellIdentifier = @"AccountCell";

static NSString* const kModelDownloadURL = @"https://s3.amazonaws.com/micro.blog/models/gemma-3-4b-it-Q5_K_M.gguf";
static NSString* const kModelDownloadSize = @"2.8 GB";
static NSString* const kMmprojDownloadURL = @"https://s3.amazonaws.com/micro.blog/models/gemma-3-4b-mmproj-F16.gguf";
static NSString* const kMmprojDownloadSize = @"700 MB";

// @"gemma-3-4b-mmproj-F16.gguf"

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
	
	[self setupModelInfo];
	
	[self updateRadioButtons];
	[self updateMenus];
	
	[self hideMessage];
	[self hideWordPressMenus];
	
	[self showGeneralPane:nil];

//	NSString* model_path = [self modelPath];
//	NSString* mmproj_path = [self mmprojPath];
//	MBLlama* llm = [[MBLlama alloc] initWithModelPath:model_path mmprojPath:mmproj_path];
//	NSString* s = [llm runPrompt:@"Describe this image in one sentence. <image>" withImage:@"..."];
//	NSLog(@"LLM output: %@", s);
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
}

- (void) setupCollectionView
{
	self.accountsCollectionView.delegate = self;
	self.accountsCollectionView.dataSource = self;
	
	[self.accountsCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"AccountCell" bundle:nil] forItemWithIdentifier:kAccountCellIdentifier];
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

- (void) setupModelInfo
{
	self.sizeField.stringValue = kModelDownloadSize;
	
	if ([self hasModel]) {
		self.modelStatusField.stringValue = @"Micro.blog can run some AI tasks on your Mac. The model has been downloaded.";
		[self.downloadButton setTitle:@"Delete"];
	}
	else {
		self.modelStatusField.stringValue = @"Micro.blog can run some AI tasks on your Mac. Download the local model?";
		[self.downloadButton setTitle:@"Download"];

		if (![self hasSupportedHardware]) {
			self.downloadButton.enabled = NO;
			self.sizeField.stringValue = @"Requires Apple M1 or later.";
		}
		else if (![self hasSupportedMemory]) {
			self.downloadButton.enabled = NO;
			self.sizeField.stringValue = @"Requires at least 16 GB of RAM.";
		}
		else if (![self hasAvailableSpace]) {
			self.downloadButton.enabled = NO;
			self.sizeField.stringValue = @"Requires 3 GB of available disk space.";
		}
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
	self.robotsPane.hidden = YES;
	[self.window.contentView addSubview:self.generalPane];
	[self.generalPane setFrameOrigin:NSMakePoint(0, 0)];
	self.generalPane.hidden = NO;
}

- (IBAction) showNotesPane:(id)sender
{
	self.generalPane.hidden = YES;
	self.robotsPane.hidden = YES;
	[self.window.contentView addSubview:self.notesPane];
	[self.notesPane setFrameOrigin:NSMakePoint(0, 0)];
	self.notesPane.hidden = NO;
}

- (IBAction) showRobotsPane:(id)sender
{
	self.generalPane.hidden = YES;
	self.notesPane.hidden = YES;
	[self.window.contentView addSubview:self.robotsPane];
	[self.robotsPane setFrameOrigin:NSMakePoint(0, 0)];
	self.robotsPane.hidden = NO;
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

#pragma mark -

- (IBAction) downloadModel:(id)sender
{
	if (self.downloadTask) {
		// if already downloading, cancel it
		[self cancelDownload];
		[self.sizeUpdateTimer invalidate];
		self.sizeUpdateTimer = nil;
	}
	else if ([self hasModel]) {
		[self deleteModel];
	}
	else {
		[self startDownload];
	}
}

- (BOOL) hasModel
{
	NSString* model_path = [self modelPath];
	NSFileManager* fm = [NSFileManager defaultManager];
	return [fm fileExistsAtPath:model_path];
}

- (BOOL) hasAvailableSpace
{
	NSURL* folder_url = [self modelsFolderURL];
	NSError* error = nil;
	NSDictionary* info = [folder_url resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
	if (error) {
		NSLog(@"Error retrieving resource values: %@", error);
		return NO;
	}

	NSNumber* free_bytes = info[NSURLVolumeAvailableCapacityForImportantUsageKey];
	NSDictionary* attrs_dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:folder_url.path error:&error];
	if (error) {
		NSLog(@"Error retrieving file system attributes: %@", error);
		return NO;
	}

	NSNumber* bytes_required = attrs_dict[NSFileSystemFreeSize];
	return free_bytes.unsignedLongLongValue > bytes_required.unsignedLongLongValue;
}

- (BOOL) hasSupportedMemory
{
	uint64_t memsize = 0;
	size_t size = sizeof(memsize);
	if (sysctlbyname("hw.memsize", &memsize, &size, NULL, 0) == 0) {
		// 16 GB
		const uint64_t required = 16ull * 1024 * 1024 * 1024;
		return memsize >= required;
	}
	
	return NO;
}

- (BOOL) hasSupportedHardware
{
	int is_arm64 = 0;
	size_t size = sizeof(is_arm64);
	if (sysctlbyname("hw.optional.arm64", &is_arm64, &size, NULL, 0) == 0) {
		return (is_arm64 != 0);
	}
	
	return NO;
}

- (NSURL *) modelsFolderURL
{
	// build destination path in Application Support/Micro.blog/Models
	NSURL* folder_url = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];

	folder_url = [folder_url URLByAppendingPathComponent:@"Micro.blog" isDirectory:YES];
	folder_url = [folder_url URLByAppendingPathComponent:@"Models" isDirectory:YES];

	[[NSFileManager defaultManager] createDirectoryAtURL:folder_url withIntermediateDirectories:YES attributes:nil error:nil];
	
	return folder_url;
}

- (NSString *) modelPath
{
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	NSURL* folder_url = [self modelsFolderURL];
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];
	
	return dest_url.path;
}

- (NSString *) mmprojPath
{
	NSURL* url = [NSURL URLWithString:kMmprojDownloadURL];
	NSURL* folder_url = [self modelsFolderURL];
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];
	
	return dest_url.path;
}

- (void) startDownload
{
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	self.modelDestinationPath = [self modelPath];
	
	// configure and show progress bar
	self.modelProgressBar.minValue = 0.0;
	self.modelProgressBar.maxValue = 100.0;
	self.modelProgressBar.doubleValue = 0.0;
	[self.modelProgressBar setHidden:NO];
	[self.modelProgressBar startAnimation:nil];
	
	// start a 1‑second timer for updating the size field
	self.sizeUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateSizeField:) userInfo:nil repeats:YES];
	
	// start the download
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	self.downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];

	self.downloadStartDate = [NSDate date];
	self.expectedBytes = 0;
	self.remainingSeconds = 0;
	self.latestDownloadedString = @"0 bytes";
	
	self.downloadTask = [self.downloadSession downloadTaskWithURL:url];
	[self.downloadTask resume];
	
	[self.downloadButton setTitle:@"Cancel"];
}

- (void) cancelDownload
{
	[self.downloadTask cancel];
	self.downloadTask = nil;
	[self.downloadSession invalidateAndCancel];
	self.downloadSession = nil;
	
	[self.sizeUpdateTimer invalidate];
	self.sizeUpdateTimer = nil;
	self.latestDownloadedString = nil;
	
	[self.modelProgressBar stopAnimation:nil];
	self.modelProgressBar.doubleValue = 0.0;
	[self.modelProgressBar setHidden:YES];
	
	self.sizeField.stringValue = kModelDownloadSize;
	[self.downloadButton setTitle:@"Download"];
	
	self.downloadStartDate = nil;
	self.expectedBytes = 0;
	self.remainingSeconds = 0;
}

- (void) finishedDownload
{
	[self setupModelInfo];
}

- (void) deleteModel
{
	[self.downloadButton setTitle:@"Download"];

	NSString* model_path = [self modelPath];
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	if ([fm fileExistsAtPath:model_path isDirectory:&is_dir] && !is_dir) {
		[fm removeItemAtPath:model_path error:NULL];
	}
}

- (NSString *) formattedRemainingTime
{
	NSTimeInterval s = self.remainingSeconds;

	if (s <= 0) {
		return @"calculating…";
	}
	else if (s < 60.0) {
		return [NSString stringWithFormat:@"%d seconds remaining", (int)round(s)];
	}
	else if (s < 3600.0) {
		return [NSString stringWithFormat:@"%d minutes remaining", (int)round(s/60.0)];
	}
	else {
		return [NSString stringWithFormat:@"%.1f hours remaining", s/3600.0];
	}
}

- (void) updateSizeField:(NSTimer *)timer
{
	if (!self.latestDownloadedString) return;

	NSString* time_s = [self formattedRemainingTime];
	self.sizeField.stringValue = [NSString stringWithFormat:@"%@ (%@, %@)", kModelDownloadSize, self.latestDownloadedString, time_s];
}

#pragma mark -

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
	if (totalBytesExpectedToWrite <= 0) {
		return;
	}
	
	double progress = ((double)totalBytesWritten / (double)totalBytesExpectedToWrite) * 100.0;
	self.modelProgressBar.doubleValue = progress;
	
	NSString* downloaded_s = [NSByteCountFormatter stringFromByteCount:totalBytesWritten countStyle:NSByteCountFormatterCountStyleFile];
	self.latestDownloadedString = downloaded_s;
	
	if (totalBytesExpectedToWrite > 0) {
		if (self.expectedBytes == 0) self.expectedBytes = totalBytesExpectedToWrite;
		
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.downloadStartDate];
		if (elapsed > 0) {
			double bytes_per_second = (double)totalBytesWritten / elapsed;
			if (bytes_per_second > 0) {
				double remaining_bytes = totalBytesExpectedToWrite - totalBytesWritten;
				self.remainingSeconds = remaining_bytes / bytes_per_second;
			}
		}
	}
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	if (self.modelDestinationPath) {
		NSURL* dest_url = [NSURL fileURLWithPath:self.modelDestinationPath];
		[[NSFileManager defaultManager] removeItemAtURL:dest_url error:nil];
		[[NSFileManager defaultManager] moveItemAtURL:location toURL:dest_url error:nil];
	}
}

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	[self.modelProgressBar stopAnimation:nil];

	if (error) {
		NSLog(@"Model download failed: %@", error);
		return;
	}

	self.modelProgressBar.doubleValue = 100.0;

	[self.sizeUpdateTimer invalidate];
	self.sizeUpdateTimer = nil;
	self.latestDownloadedString = nil;

	self.downloadTask = nil;
	[self.downloadSession invalidateAndCancel];
	self.downloadSession = nil;

	self.remainingSeconds = 0;
	self.downloadStartDate = nil;
	self.expectedBytes = 0;
	
	[self finishedDownload];
}

@end

//
//  RFPreferencesController.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPreferencesController.h"

#import "RFMacros.h"
#import "RFXMLLinkParser.h"
#import "RFWordpressController.h"
#import "NSString+Extras.h"
#import "UUHttpSession.h"
#import "UUString.h"

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

	[self setupFields];
	[self setupNotifications];
	
	[self updateRadioButtons];
	[self hideMessage];
}

- (void) setupFields
{
	self.returnButton.alphaValue = 0.0;
	self.websiteField.delegate = self;
	
	NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:@"ExternalBlogURL"];
	if (s) {
		self.websiteField.stringValue = s;
	}
}

- (void) setupNotifications
{
}

#pragma mark -

- (IBAction) setHostedBlog:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ExternalBlogIsPreferred"];
	[self updateRadioButtons];
}

- (IBAction) setWordPressBlog:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ExternalBlogIsPreferred"];
	[self updateRadioButtons];
}

- (IBAction) returnButtonPressed:(id)sender
{
	[self hideReturnButton];
	[self checkWebsite];
}

- (void) controlTextDidChange:(NSNotification *)notification
{
	NSString* s = self.websiteField.stringValue;
	if (s.length > 0) {
		[self showReturnButton];
	}
	else {
		[self hideReturnButton];
	}
}

- (IBAction) websiteTextChanged:(id)sender
{
	[self hideReturnButton];
	[self checkWebsite];
}

//	[[NSUserDefaults standardUserDefaults] setObject:self.selectedFormat forKey:@"ExternalBlogFormat"];
//	[[NSUserDefaults standardUserDefaults] setObject:self.selectedCategory forKey:@"ExternalBlogCategory"];

#pragma mark -

- (void) showMessage:(NSString *)message
{
	self.messageField.stringValue = message;
	
	if (self.messageTopConstraint.constant < -1) {
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
			NSRect win_r = self.window.frame;
			win_r.size.height += 44;
			win_r.origin.y -= 44;

			context.duration = [self.window animationResizeTime:win_r];
			
			self.messageTopConstraint.animator.constant = -1;
			[self.window.animator setFrame:win_r display:YES];
		} completionHandler:^{
		}];
	}
}

- (void) hideMessage
{
	self.messageTopConstraint.constant = -44;
	
	NSSize win_size = self.window.frame.size;
	win_size.height -= 44;
	[self.window setContentSize:win_size];
}

- (void) updateRadioButtons
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ExternalBlogIsPreferred"]) {
		self.publishHostedBlog.state = NSControlStateValueOn;
		self.publishWordPressBlog.state = NSControlStateValueOff;
	}
	else {
		self.publishHostedBlog.state = NSControlStateValueOff;
		self.publishWordPressBlog.state = NSControlStateValueOn;
	}
}

- (void) showReturnButton
{
	self.returnButton.animator.alphaValue = 1.0;
}

- (void) hideReturnButton
{
	self.returnButton.animator.alphaValue = 0.0;
}

- (void) checkWebsite
{
	[self.progressSpinner startAnimation:nil];

	NSString* full_url = [self normalizeURL:self.websiteField.stringValue];
	[[NSUserDefaults standardUserDefaults] setObject:full_url forKey:@"ExternalBlogURL"];

	UUHttpRequest* request = [UUHttpRequest getRequest:full_url queryArguments:nil];
	[UUHttpSession executeRequest:request completionHandler:^(UUHttpResponse* response) {
		RFXMLLinkParser* rsd_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"EditURI"];
		if ([rsd_parser.foundURLs count] > 0) {
			NSString* rsd_url = [rsd_parser.foundURLs firstObject];
            RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];

                self.wordpressController = [[RFWordpressController alloc] initWithWebsite:full_url rsdURL:rsd_url];
				[self.window beginSheet:self.wordpressController.window completionHandler:^(NSModalResponse returnCode) {
					if (returnCode == NSModalResponseOK) {
						[self showMessage:@"Weblog settings have been updated."];
					}
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

					[[NSUserDefaults standardUserDefaults] setObject:micropub_state forKey:@"ExternalMicropubState"];
					[[NSUserDefaults standardUserDefaults] setObject:token_endpoint forKey:@"ExternalMicropubTokenEndpoint"];
					[[NSUserDefaults standardUserDefaults] setObject:micropub_endpoint forKey:@"ExternalMicropubPostingEndpoint"];

					RFDispatchMainAsync (^{
						[self.progressSpinner stopAnimation:nil];
						[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:auth_with_params]];
					});
				}
			}
			else {
				RFDispatchMainAsync (^{
					[self.progressSpinner stopAnimation:nil];
					// FIXME
//					[UIAlertView uuShowTwoButtonAlert:@"Error Discovering Settings" message:@"Could not find the XML-RPC endpoint or Micropub API for your weblog. Please see help.micro.blog for troubleshooting tips." buttonOne:@"Visit Help" buttonTwo:@"OK" completionHandler:^(NSInteger buttonIndex) {
//						if (buttonIndex == 0) {
//							[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://help.micro.blog/"]];
//						}
//					}];
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

@end

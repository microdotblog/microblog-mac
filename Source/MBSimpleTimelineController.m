//
//  MBSimpleTimelineController.m
//  Micro.blog
//
//  Created by Manton Reece on 4/4/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBSimpleTimelineController.h"

#import "NSObject+SharedTimeline.h"
#import "NSAppearance+Extras.h"
#import "RFConstants.h"

@implementation MBSimpleTimelineController

- (id) initWithURL:(NSString *)url
{
	self = [super initWithNibName:@"Simple" bundle:nil];
	if (self) {
		self.url = url;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self setupWebView];
	[self setupNotifications];
}

- (void) setupWebView
{
	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}
	
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.view.window];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKeyNotification:) name:NSWindowDidResignKeyNotification object:self.view.window];
}

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self applyForegroundJS:self.webView];
}

- (void) windowDidResignKeyNotification:(NSNotification *)notification
{
	[self applyBackgroundJS:self.webView];
}

#pragma mark -

- (void) keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@"\r"]) {
		if ([self.selectedPostID length] > 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:kShowConversationNotification object:self userInfo:@{ kShowConversationPostIDKey: self.selectedPostID }];
		}
	}
	else {
		[super keyDown:event];
	}
}

- (void) moveUp:(id)sender
{
	NSString* js;
	
	NSString* last_selected_id = nil;
	if ([self.selectedPostID length] > 0) {
		last_selected_id = self.selectedPostID;
		
		// select previous
		js = [NSString stringWithFormat:@"var div = document.getElementById('post_%@');\
			var next_div = div.previousElementSibling;\
			if (next_div && next_div.classList.contains('post')) {\
				next_div.classList.add('is_selected');\
			};", self.selectedPostID];
	}
	else {
		// select first
		js = @"var div = document.querySelector('.post');\
			div.classList.add('is_selected');";
	}
	
	[self.webView stringByEvaluatingJavaScriptFromString:js];
	[self updateSelectionFromMove];
	
	// deselect last if changed
	if (last_selected_id && ![last_selected_id isEqualToString:self.selectedPostID]) {
		[self setSelected:NO withPostID:last_selected_id];
	}
}

- (void) moveDown:(id)sender
{
	NSString* js;
	
	NSString* last_selected_id = nil;
	if ([self.selectedPostID length] > 0) {
		last_selected_id = self.selectedPostID;
				
		// select next
		js = [NSString stringWithFormat:@"var div = document.getElementById('post_%@');\
   var next_div = div.nextElementSibling;\
   if (next_div && next_div.classList.contains('post')) {\
	next_div.classList.add('is_selected');\
   };", self.selectedPostID];
	}
	else {
		// select first
		js = @"var div = document.querySelector('.post');\
  div.classList.add('is_selected');";
	}
	
	[self.webView stringByEvaluatingJavaScriptFromString:js];
	[self updateSelectionFromMove];
	
	// deselect last if changed
	if (last_selected_id && ![last_selected_id isEqualToString:self.selectedPostID]) {
		[self setSelected:NO withPostID:last_selected_id];
	}
}

- (IBAction) reply:(id)sender
{
	if (self.selectedPostID.length > 0) {
		NSString* url = [NSString stringWithFormat:@"microblog://reply/%@", self.selectedPostID];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
	}
}

- (NSString *) topPostID
{
	// class: "post post_1234"
	NSString* js = @"$('.post')[0].id.split('_')[1]";
	NSString* post_id = [self.webView stringByEvaluatingJavaScriptFromString:js];
	return post_id;
}

- (NSString *) findSelectedPostID
{
	// get selection ignoring current selected post ID
	NSString* js = [NSString stringWithFormat:@"var divs = document.querySelectorAll('div.post.is_selected');"
		"if (divs.length > 0) {"
		"	var result = Array.from(divs).find(post => post.id !== 'post_%@');"
		"	if (result == null) {"
		"		'%@';"
		"	}"
		"	else {"
		"		result.id.split('_')[1];"
		"	}"
		"}"
		"else {"
		"	'%@';"
		"}", self.selectedPostID, self.selectedPostID, self.selectedPostID];
	NSString* post_id = [self.webView stringByEvaluatingJavaScriptFromString:js];
	return post_id;
}

- (void) setSelected:(BOOL)isSelected withPostID:(NSString *)postID
{
	NSString* js;
	if (isSelected) {
		js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_selected');", postID];
	}
	else {
		js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_selected');", postID];
	}
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) setPressed:(BOOL)isPressed withPostID:(NSString *)postID
{
	NSString* js;
	if (isPressed) {
		js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_pressed');", postID];
	}
	else {
		js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_pressed');", postID];
	}
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) updateSelectionFromMove
{
	self.selectedPostID = [self findSelectedPostID];
	NSString* js = [NSString stringWithFormat:@"document.getElementById('post_%@').scrollIntoView({ behavior: 'smooth', block: 'nearest' });", self.selectedPostID];
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (NSRect) rectOfPostID:(NSString *)postID
{
	NSString* top_js = [NSString stringWithFormat:@"$('#post_%@').position().top;", postID];
	NSString* height_js = [NSString stringWithFormat:@"$('#post_%@').height();", postID];
	NSString* scroll_js = [NSString stringWithFormat:@"window.pageYOffset;"];

	NSString* top_s = [self.webView stringByEvaluatingJavaScriptFromString:top_js];
	NSString* height_s = [self.webView stringByEvaluatingJavaScriptFromString:height_js];
	NSString* scroll_s = [self.webView stringByEvaluatingJavaScriptFromString:scroll_js];
	
//	CGFloat top_f = self.webView.bounds.size.height - [top_s floatValue] - [height_s floatValue];
	CGFloat top_f = [top_s floatValue] - [height_s floatValue];
	top_f += [scroll_s floatValue];
	
	// adjust to full cell width
	CGFloat left_f = 0.0;
	CGFloat width_f = self.webView.bounds.size.width;
	
	return NSMakeRect (left_f, top_f, width_f, [height_s floatValue]);
}

@end

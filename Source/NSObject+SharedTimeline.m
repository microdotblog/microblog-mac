//
//  NSObject+SharedTimeline.m
//  Micro.blog
//
//  Created by Manton Reece on 4/5/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "NSObject+SharedTimeline.h"

#import "NSColor+Extras.h"

@implementation NSObject (SharedTimeline)

- (void) setupCSS:(WebView *)webView;
{
	NSAppearance* appearance = [[NSApplication sharedApplication] effectiveAppearance];
	__block NSString* selected_hex = nil;
	__block NSString* pressed_hex = nil;
	__block NSString* unfocused_background_hex = nil;
	__block NSString* unfocused_text_hex = nil;

	[appearance performAsCurrentDrawingAppearance:^{
		selected_hex = [[NSColor selectedContentBackgroundColor] mb_hexString];
		pressed_hex = [[NSColor colorNamed:@"color_row_pressed"] mb_hexString];
		unfocused_background_hex = [[NSColor colorNamed:@"color_row_unfocused_selection"] mb_hexString];
		unfocused_text_hex = [[NSColor textColor] mb_hexString];
	}];

	NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Posts" ofType:@"css"];
	NSString* template_css = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];

	NSString* s = template_css;
	s = [s stringByReplacingOccurrencesOfString:@"[SELECTED_BACKGROUND]" withString:selected_hex];
	s = [s stringByReplacingOccurrencesOfString:@"[PRESSED_BACKGROUND]" withString:pressed_hex];
	s = [s stringByReplacingOccurrencesOfString:@"[UNFOCUSED_BACKGROUND]" withString:unfocused_background_hex];
	s = [s stringByReplacingOccurrencesOfString:@"[UNFOCUSED_TEXT]" withString:unfocused_text_hex];

	[self injectCSS:s intoWebView:webView];
}

- (void) injectCSS:(NSString *)cssString intoWebView:(WebView *)webView
{
	NSString* js = [NSString stringWithFormat:@"var style = document.getElementById('mb-posts-css');"
						"if (!style) {"
						"	style = document.createElement('style');"
						"	style.id = 'mb-posts-css';"
						"	document.getElementsByTagName('head')[0].appendChild(style);"
						"}"
						"style.type = 'text/css';"
						"style.innerHTML = `%@`;", cssString];
	[webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) applyForegroundJS:(WebView *)webView
{
	NSString* js = @"var container = document.getElementsByClassName('container')[0];"
		"container.classList.remove('blur');";
	[webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) applyBackgroundJS:(WebView *)webView
{
	NSString* js = @"var container = document.getElementsByClassName('container')[0];"
		"container.classList.add('blur');";
	[webView stringByEvaluatingJavaScriptFromString:js];
}

@end

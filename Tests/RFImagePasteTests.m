#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import "RFHighlightingTextView.h"
#import "RFConstants.h"

// Link with RFHighlightingTextView.m, Cocoa, ImageIO, and UniformTypeIdentifiers.
// A private pasteboard keeps the user's clipboard and account untouched.
@interface RFSettings : NSObject
+ (void) addTemporaryFolder:(NSString *)path;
@end
@implementation RFSettings
+ (void) addTemporaryFolder:(NSString *)path {}
@end

@interface RFAutoCompleteCache : NSObject
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler;
@end
@implementation RFAutoCompleteCache
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler { handler(@[]); }
@end

static NSPasteboard* test_pasteboard;
@interface NSPasteboard (ImagePasteTests)
+ (NSPasteboard *) imageTestPasteboard;
@end
@implementation NSPasteboard (ImagePasteTests)
+ (NSPasteboard *) imageTestPasteboard { return test_pasteboard; }
@end

static NSData* image_data(UTType* type, NSUInteger frames)
{
	NSMutableData* data = [NSMutableData data];
	CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)type.identifier, frames, NULL);
	NSCAssert(destination != NULL, @"Create encoded image fixture");
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, 8, 8, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	for (NSUInteger index = 0; index < frames; index++) {
		CGContextSetRGBFillColor(context, index == 0 ? 1 : 0, 0, index == 0 ? 0 : 1, 1);
		CGContextFillRect(context, CGRectMake(0, 0, 2, 2));
		CGImageRef image = CGBitmapContextCreateImage(context);
		NSDictionary* properties = @{ (__bridge NSString*)kCGImagePropertyGIFDictionary: @{ (__bridge NSString*)kCGImagePropertyGIFDelayTime: @0.1 } };
		CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
		CGImageRelease(image);
	}
	NSCAssert(CGImageDestinationFinalize(destination), @"Finalize encoded image fixture");
	CGContextRelease(context);
	CGColorSpaceRelease(space);
	CFRelease(destination);
	return data;
}

static void paste(RFHighlightingTextView* editor)
{
	Method general = class_getClassMethod([NSPasteboard class], @selector(generalPasteboard));
	Method isolated = class_getClassMethod([NSPasteboard class], @selector(imageTestPasteboard));
	method_exchangeImplementations(general, isolated);
	@try {
		[editor paste:nil];
	}
	@finally {
		method_exchangeImplementations(general, isolated);
	}
}

static void write_image(NSDictionary* representations)
{
	[test_pasteboard clearContents];
	NSPasteboardItem* item = [NSPasteboardItem new];
	for (NSString* type in representations) {
		[item setData:representations[type] forType:type];
	}
	NSCAssert([test_pasteboard writeObjects:@[item]], @"Write image representations");
}

int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		test_pasteboard = [NSPasteboard pasteboardWithUniqueName];
		RFHighlightingTextView* editor = [[RFHighlightingTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
		editor.richText = YES;
		editor.importsGraphics = NO;
		editor.string = @"Caption";
		editor.selectedRange = NSMakeRange(editor.string.length, 0);
		NSCAssert([[editor readablePasteboardTypes] containsObject:UTTypeGIF.identifier] && [[editor readablePasteboardTypes] containsObject:UTTypeJPEG.identifier], @"Enable Paste for GIF-only and JPEG-only clipboards");

		NSMutableArray* notifications = [NSMutableArray array];
		id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kAttachFilesNotification object:editor queue:nil usingBlock:^(NSNotification* notification) {
			NSArray* paths = notification.userInfo[kAttachFilesPathsKey];
			NSCAssert(paths.count == 1, @"Attach one image, with the editor as sender");
			[notifications addObject:paths.firstObject];
		}];
		NSData* gif = image_data(UTTypeGIF, 2);
		NSData* jpeg = image_data(UTTypeJPEG, 1);
		NSData* png = image_data(UTTypePNG, 1);
		NSData* tiff = image_data(UTTypeTIFF, 1);
		NSArray* cases = @[
			@{ @"types": @{ UTTypeGIF.identifier: gif }, @"extension": @"gif", @"data": gif },
			@{ @"types": @{ UTTypeGIF.identifier: gif, UTTypeJPEG.identifier: jpeg, NSPasteboardTypePNG: png, NSPasteboardTypeTIFF: tiff }, @"extension": @"gif", @"data": gif },
			@{ @"types": @{ UTTypeJPEG.identifier: jpeg }, @"extension": @"jpg", @"data": jpeg },
			@{ @"types": @{ UTTypeJPEG.identifier: jpeg, NSPasteboardTypePNG: png, NSPasteboardTypeTIFF: tiff }, @"extension": @"jpg", @"data": jpeg },
			@{ @"types": @{ NSPasteboardTypePNG: png }, @"extension": @"png", @"data": png },
			@{ @"types": @{ NSPasteboardTypeTIFF: tiff }, @"extension": @"jpg" },
			@{ @"types": @{ UTTypeGIF.identifier: [@"invalid GIF" dataUsingEncoding:NSUTF8StringEncoding], NSPasteboardTypePNG: png }, @"extension": @"png", @"data": png }
		];
		for (NSDictionary* test_case in cases) {
			write_image(test_case[@"types"]);
			NSUInteger previous_count = notifications.count;
			paste(editor);
			NSCAssert(notifications.count == previous_count + 1, @"Route image data through attachment notification");
			NSCAssert([editor.string isEqualToString:@"Caption"] && editor.textStorage.length == @"Caption".length, @"Never insert the image into the rich-text editor");
			NSString* path = notifications.lastObject;
			NSCAssert([path.pathExtension isEqualToString:test_case[@"extension"]], @"Choose an extension the attachment pipeline understands");
			NSData* saved = [NSData dataWithContentsOfFile:path];
			if (test_case[@"data"]) {
				NSCAssert([saved isEqualToData:test_case[@"data"]], @"Preserve the original encoded bytes");
			}
			CGImageSourceRef image_source = CGImageSourceCreateWithData((__bridge CFDataRef)saved, NULL);
			NSCAssert(image_source != NULL, @"Saved attachment must decode");
			if ([path.pathExtension isEqualToString:@"gif"]) {
				NSCAssert(CGImageSourceGetCount(image_source) == 2, @"Keep both animation frames, even when static alternatives exist");
			}
			if ([path.pathExtension isEqualToString:@"jpg"]) {
				NSCAssert(CFEqual(CGImageSourceGetType(image_source), (__bridge CFStringRef)UTTypeJPEG.identifier), @"TIFF fallback and JPEG data produce real JPEG files");
			}
			CFRelease(image_source);
		}

		NSString* gif_path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"gif"]];
		NSCAssert([gif writeToFile:gif_path atomically:YES], @"Write a copied GIF file fixture");
		[test_pasteboard clearContents];
		NSCAssert([test_pasteboard writeObjects:@[[NSURL fileURLWithPath:gif_path]]], @"Copy the file URL as Finder does");
		paste(editor);
		NSCAssert([notifications.lastObject isEqualToString:gif_path], @"Keep the existing file URL attachment path");

		[test_pasteboard clearContents];
		[test_pasteboard setString:@" text" forType:NSPasteboardTypeString];
		NSUInteger previous_count = notifications.count;
		paste(editor);
		NSCAssert([editor.string isEqualToString:@"Caption text"] && notifications.count == previous_count, @"Ordinary text still uses the native text paste path");

		[[NSNotificationCenter defaultCenter] removeObserver:observer];
		for (NSString* path in notifications) {
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		}
		[test_pasteboard releaseGlobally];
		NSLog(@"Image paste tests passed: GIF animation, format preference, JPEG, PNG, TIFF, invalid-data fallback, file URLs, and text.");
	}
	return 0;
}

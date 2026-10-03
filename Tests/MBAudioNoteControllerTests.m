#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "MBAudioNoteController.h"
#import "MBNote.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"

// Link the production controller with these network/settings/encryption test doubles.
// No real microphone, account, Keychain, or server is used.
static NSString* gUsername = @"test-account";
static BOOL gEncryptionFails;
static NSMutableArray* gRequests;
NSString* const kUUHttpSessionErrorDomain = @"test-http";
NSString* const kUUHttpSessionHttpErrorCodeKey = @"status";

@implementation RFSettings
+ (NSString *) stringForKey:(NSString *)key
{
	return gUsername;
}
@end

@implementation MBNote
+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)key
{
	return gEncryptionFails ? nil : [NSString stringWithFormat:@"encrypted:%@:%@", key, text];
}
@end

@implementation UUHttpResponse
@end

@implementation RFClient
- (instancetype) initWithPath:(NSString *)path
{
	self = [super init];
	self.path = path;
	return self;
}
- (UUHttpRequest *) getWithCompletion:(void (^)(UUHttpResponse* response))handler
{
	[gRequests addObject:@{ @"path": self.path, @"method": @"GET", @"completion": [handler copy] }];
	return nil;
}
- (UUHttpRequest *) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse* response))handler
{
	[gRequests addObject:@{ @"path": self.path, @"method": @"POST", @"params": params, @"completion": [handler copy] }];
	return nil;
}
- (UUHttpRequest *) uploadFileData:(NSData *)data named:(NSString *)name filename:(NSString *)filename contentType:(NSString *)contentType httpMethod:(NSString *)method queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	[gRequests addObject:@{ @"path": self.path, @"method": method, @"data": data, @"name": name, @"filename": filename, @"type": contentType, @"completion": [handler copy] }];
	return nil;
}
@end

@interface MBAudioNoteController (Testing)
- (void) processTasksResponse:(id)response;
- (void) pollForTranscript;
- (void) beginPolling;
- (void) uploadRecordedFile;
- (void) dismissSheet;
- (void) requestMicrophoneAccess;
- (void) showRecordingError:(NSString *)message;
- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
@end

@interface MBAudioNoteSheetTestController : MBAudioNoteController
@property (assign) BOOL requestedAccess;
@end
@implementation MBAudioNoteSheetTestController
- (void) requestMicrophoneAccess
{
	self.requestedAccess = YES;
}
@end

@interface MBAudioNoteTestController : MBAudioNoteController
@property (assign) BOOL dismissedSheet;
@property (copy) NSString* recordingError;
@end
@implementation MBAudioNoteTestController
- (void) dismissSheet
{
	self.dismissedSheet = YES;
}
- (void) showRecordingError:(NSString *)message
{
	self.recordingError = message;
}
@end

static UUHttpResponse* Response(NSInteger status, id body)
{
	UUHttpResponse* response = [[UUHttpResponse alloc] init];
	response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://micro.blog/notes/audio"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
	response.parsedResponse = body;
	if (status >= 400) {
		response.httpError = [NSError errorWithDomain:kUUHttpSessionErrorDomain code:UUHttpSessionErrorHttpError userInfo:@{ kUUHttpSessionHttpErrorCodeKey: @(status) }];
	}
	return response;
}

static void Pump(void)
{
	[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void CompleteRequest(NSDictionary* request, NSInteger status, id body)
{
	void (^handler)(UUHttpResponse*) = request[@"completion"];
	handler(Response(status, body));
	Pump();
}

static MBAudioNoteTestController* Controller(void (^completion)(MBNote*, NSString*, NSString*))
{
	MBAudioNoteTestController* controller = [[MBAudioNoteTestController alloc] initWithNotebookID:@42 secretKey:@"test-key" completion:completion];
	[controller setValue:@"our-task" forKey:@"audioID"];
	[controller setValue:[NSDate date] forKey:@"pollingStartedAt"];
	return controller;
}

static NSDictionary* CompletedTask(void)
{
	return @{ @"tasks": @[ @{ @"id": @"our-task", @"status": @"completed", @"text": @"Recorded words" } ] };
}

// Feed real PCM samples into the production capture delegate and finalize its AAC writer.
static NSURL* RecordSyntheticAudio(MBAudioNoteTestController* controller)
{
	NSURL* file_url = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSString stringWithFormat:@"audio-note-test-%@.m4a", NSUUID.UUID.UUIDString]];
	[controller setValue:file_url forKey:@"fileURL"];
	NSView* waveform = [[NSClassFromString(@"MBAudioNoteWaveformView") alloc] initWithFrame:NSMakeRect(0, 0, 512, 100)];
	[controller setValue:waveform forKey:@"waveformView"];
	dispatch_queue_t queue = [controller valueForKey:@"captureQueue"];
	dispatch_sync(queue, ^{
		NSError* error = nil;
		AVAssetWriter* writer = [[AVAssetWriter alloc] initWithURL:file_url fileType:AVFileTypeAppleM4A error:&error];
		AVAssetWriterInput* input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:@{ AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @44100, AVNumberOfChannelsKey: @1, AVEncoderBitRateKey: @64000 }];
		[writer addInput:input];
		[controller setValue:writer forKey:@"writer"];
		[controller setValue:input forKey:@"writerInput"];
		[controller setValue:@YES forKey:@"recording"];

		AudioStreamBasicDescription format = { .mSampleRate = 44100, .mFormatID = kAudioFormatLinearPCM, .mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, .mBytesPerPacket = 4, .mFramesPerPacket = 1, .mBytesPerFrame = 4, .mChannelsPerFrame = 1, .mBitsPerChannel = 32 };
		CMAudioFormatDescriptionRef description = NULL;
		NSCAssert(CMAudioFormatDescriptionCreate(NULL, &format, 0, NULL, 0, NULL, NULL, &description) == noErr, @"PCM format");
		CMBlockBufferRef block = NULL;
		NSCAssert(CMBlockBufferCreateWithMemoryBlock(NULL, NULL, 4096 * sizeof(float), NULL, NULL, 0, 4096 * sizeof(float), 0, &block) == noErr, @"PCM block");
		float samples[4096];
		for (NSUInteger i = 0; i < 4096; i++) {
			samples[i] = 0.5 * sin(i * 2 * M_PI * 440 / 44100);
		}
		CMBlockBufferReplaceDataBytes(samples, block, 0, sizeof(samples));
		CMSampleBufferRef buffer = NULL;
		NSCAssert(CMAudioSampleBufferCreateReadyWithPacketDescriptions(NULL, block, description, 4096, CMTimeMake(0, 44100), NULL, &buffer) == noErr, @"PCM sample buffer");
		[controller captureOutput:nil didOutputSampleBuffer:buffer fromConnection:nil];
		CFRelease(buffer);
		CFRelease(block);
		CFRelease(description);
		NSCAssert(writer.status == AVAssetWriterStatusWriting, @"Production delegate must start and append samples");
		[input markAsFinished];
		[writer finishWritingWithCompletionHandler:^{}];
	});
	AVAssetWriter* writer = [controller valueForKey:@"writer"];
	NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:10];
	while (writer.status == AVAssetWriterStatusWriting && deadline.timeIntervalSinceNow > 0) {
		Pump();
	}
	NSCAssert(writer.status == AVAssetWriterStatusCompleted, @"AAC must finalize: %@", writer.error);
	NSCAssert([NSData dataWithContentsOfURL:file_url].length > 0, @"AAC output must be nonempty");
	Pump();
	NSCAssert([[[waveform valueForKey:@"levels"] lastObject] floatValue] > 0.49, @"Waveform must meter real PCM samples");
	return file_url;
}

int main(int argc, const char* argv[])
{
	@autoreleasepool {
		if (argc > 1 && strcmp(argv[1], "--layout") == 0) {
			[NSApplication sharedApplication];
			MBAudioNoteSheetTestController* layout_controller = [[MBAudioNoteSheetTestController alloc] initWithNotebookID:@42 secretKey:@"test-key" completion:nil];
			NSWindow* parent_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 500) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			[parent_window orderFront:nil];
			[layout_controller beginSheetForWindow:parent_window];
			NSWindow* window = layout_controller.window;
			NSCAssert(window != nil && window.contentView.subviews.count == 6, @"Programmatic sheet must create all controls");
			NSCAssert(window.sheetParent == parent_window && layout_controller.requestedAccess, @"Present the sheet before requesting microphone access");
			NSPopUpButton* popup = [layout_controller valueForKey:@"inputsPopup"];
			[popup addItemWithTitle:@"MacBook Pro Microphone"];
			[popup addItemWithTitle:@"External Microphone"];
			popup.enabled = YES;
			NSButton* upload_button = [layout_controller valueForKey:@"uploadButton"];
			upload_button.enabled = YES;
			NSTextField* status_field = [layout_controller valueForKey:@"statusField"];
			status_field.stringValue = @"Recording…";
			NSView* waveform = [layout_controller valueForKey:@"waveformView"];
			NSMutableArray* levels = [NSMutableArray array];
			for (NSInteger i = 0; i < 100; i++) {
				[levels addObject:@(0.1 + fabs(sin(i * 0.25)) * 0.5)];
			}
			[waveform setValue:levels forKey:@"levels"];
			window.contentView.wantsLayer = YES;
			window.contentView.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
			Pump();
			[window.contentView layoutSubtreeIfNeeded];
			NSCAssert(status_field.frame.size.height < 24, @"Single-line status must not reserve extra vertical space");
			NSCAssert(fabs(NSMinY(status_field.frame) - NSMaxY(waveform.frame) - 12) < 0.1, @"Waveform must sit 12 points below the status label");
			NSCAssert(popup.frame.origin.x < upload_button.frame.origin.x && popup.frame.origin.y < waveform.frame.origin.y, @"Input left, buttons right, waveform above");
			NSBitmapImageRep* rep = [window.contentView bitmapImageRepForCachingDisplayInRect:window.contentView.bounds];
			[window.contentView cacheDisplayInRect:window.contentView.bounds toBitmapImageRep:rep];
			[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"/private/tmp/microblog-audio-note-layout.png" atomically:YES];
			[layout_controller cancel:nil];
			[parent_window orderOut:nil];
			NSLog(@"Passed sheet construction/layout checks without requesting microphone access.");
			return 0;
		}
		gRequests = [NSMutableArray array];
		__block NSInteger completion_count = 0;
		__block MBNote* saved_note;
		MBAudioNoteTestController* controller = Controller(^(MBNote* note, NSString* text, NSString* error) {
			completion_count++;
			saved_note = note;
			NSCAssert(error == nil, @"Unexpected failure: %@", error);
		});
		[controller beginPolling];
		NSCAssert([[controller valueForKey:@"pollTimer"] timeInterval] == 2, @"Poll interval must be two seconds");
		[controller pollForTranscript];
		[controller pollForTranscript];
		NSCAssert(gRequests.count == 1, @"Polls must not overlap");
		CompleteRequest(gRequests.lastObject, 503, @{ @"error": @"Unavailable" });
		[controller pollForTranscript];
		CompleteRequest(gRequests.lastObject, 200, @{ @"tasks": @[ @{ @"id": @"another-task", @"status": @"completed", @"text": @"Not our note" }, @{ @"id": @"our-task", @"status": @"processing" } ] });
		NSCAssert(gRequests.count == 2 && completion_count == 0, @"Must ignore other tasks and wait for processing");
		[controller processTasksResponse:CompletedTask()];
		[controller processTasksResponse:CompletedTask()];
		NSDictionary* save_request = gRequests.lastObject;
		NSCAssert(gRequests.count == 3 && [save_request[@"path"] isEqual:@"/notes"], @"Completed task must save once");
		NSDictionary* expected_params = @{ @"text": @"encrypted:test-key:Recorded words", @"is_encrypted": @YES, @"notebook_id": @42 };
		NSCAssert([save_request[@"params"] isEqual:expected_params], @"Must encrypt with captured key and notebook, never POST plaintext");
		CompleteRequest(save_request, 200, @{ @"id": @101 });
		CompleteRequest(save_request, 200, @{ @"id": @101 });
		[controller pollForTranscript];
		NSCAssert(completion_count == 1 && [saved_note.noteID isEqual:@101] && saved_note.isEncrypted && [saved_note.text isEqual:@"Recorded words"], @"Exactly one saved note");
		NSCAssert([controller valueForKey:@"pollTimer"] == nil, @"Completion must stop polling");
		[gRequests removeAllObjects];

		__block NSString* failure;
		controller = Controller(^(MBNote* note, NSString* text, NSString* error) { failure = error; });
		[controller processTasksResponse:@{ @"tasks": @[ @{ @"id": @"our-task", @"status": @"failed", @"error": @"Transcription failed" } ] }];
		NSCAssert([failure isEqual:@"Transcription failed"] && gRequests.count == 0, @"Failed task must not save");
		controller = Controller(^(MBNote* note, NSString* text, NSString* error) { failure = error; });
		[controller processTasksResponse:@{ @"tasks": @[ @{ @"id": @"our-task", @"status": @"completed", @"text": @" \n" } ] }];
		NSCAssert(failure.length > 0 && gRequests.count == 0, @"Empty transcript must not save");
		controller = Controller(^(MBNote* note, NSString* text, NSString* error) { failure = error; });
		[controller processTasksResponse:@{ @"tasks": @"invalid" }];
		NSCAssert(failure.length > 0 && gRequests.count == 0, @"Malformed payload must not save");
		gEncryptionFails = YES;
		controller = Controller(^(MBNote* note, NSString* text, NSString* error) {
			NSCAssert(note == nil && [text isEqual:@"Recorded words"] && error.length > 0, @"Keep transcript on encryption failure");
		});
		[controller processTasksResponse:CompletedTask()];
		NSCAssert(gRequests.count == 0, @"Encryption failure must not POST");
		gEncryptionFails = NO;

		controller = Controller(^(MBNote* note, NSString* text, NSString* error) {
			NSCAssert(note == nil && [text isEqual:@"Recorded words"] && error.length > 0, @"Keep transcript on save failure");
		});
		[controller processTasksResponse:CompletedTask()];
		CompleteRequest(gRequests.lastObject, 502, nil);
		[controller pollForTranscript];
		[controller processTasksResponse:CompletedTask()];
		NSCAssert(gRequests.count == 1, @"Never repeat an ambiguous save POST");
		[gRequests removeAllObjects];

		controller = Controller(nil);
		[controller pollForTranscript];
		NSDictionary* pending_request = gRequests.lastObject;
		[controller cancel:nil];
		CompleteRequest(pending_request, 200, CompletedTask());
		NSCAssert(gRequests.count == 1, @"Late poll after Cancel must not save");
		[gRequests removeAllObjects];
		controller = Controller(nil);
		gUsername = @"different-account";
		[controller pollForTranscript];
		NSCAssert(gRequests.count == 0 && [[controller valueForKey:@"finished"] boolValue], @"Do not use another account's credentials");
		gUsername = @"test-account";
		controller = Controller(nil);
		[controller setValue:[NSDate dateWithTimeIntervalSinceNow:-901] forKey:@"pollingStartedAt"];
		[controller pollForTranscript];
		NSCAssert(gRequests.count == 0 && [[controller valueForKey:@"finished"] boolValue], @"Polling must time out");

		controller = Controller(nil);
		NSURL* file_url = RecordSyntheticAudio(controller);
		[controller setValue:@YES forKey:@"uploading"];
		[controller uploadRecordedFile];
		NSDictionary* upload_request = gRequests.lastObject;
		NSCAssert([upload_request[@"path"] isEqual:@"/notes/audio"] && [upload_request[@"name"] isEqual:@"file"] && [upload_request[@"type"] isEqual:@"audio/mp4"] && [upload_request[@"filename"] hasSuffix:@".m4a"], @"Correct multipart contract");
		CompleteRequest(upload_request, 403, @{ @"error": @"Enable AI features" });
		NSCAssert(gRequests.count == 1 && ![[controller valueForKey:@"uploading"] boolValue] && [controller valueForKey:@"pollTimer"] == nil && [NSFileManager.defaultManager fileExistsAtPath:file_url.path], @"Upload failure must preserve audio and allow explicit retry, without polling");
		[controller uploadRecordedFile];
		upload_request = gRequests.lastObject;
		CompleteRequest(upload_request, 202, @{ @"id": @"new-task" });
		NSCAssert([[controller valueForKey:@"audioID"] isEqual:@"new-task"] && controller.dismissedSheet && [controller valueForKey:@"pollTimer"] != nil, @"Upload must close sheet and start polling");
		dispatch_sync([controller valueForKey:@"captureQueue"], ^{});
		NSCAssert(![NSFileManager.defaultManager fileExistsAtPath:file_url.path], @"Upload must delete local audio");
		[controller cancel:nil];
		[gRequests removeAllObjects];

		controller = Controller(nil);
		file_url = RecordSyntheticAudio(controller);
		[controller uploadRecordedFile];
		upload_request = gRequests.lastObject;
		[controller cancel:nil];
		CompleteRequest(upload_request, 202, @{ @"id": @"cancelled-task" });
		dispatch_sync([controller valueForKey:@"captureQueue"], ^{});
		NSCAssert(![NSFileManager.defaultManager fileExistsAtPath:file_url.path] && [controller valueForKey:@"pollTimer"] == nil, @"Cancel must delete audio and ignore late upload result");
		[gRequests removeAllObjects];

		NSLog(@"Passed audio capture/encoding, multipart, polling, single encrypted save, failure, account-change and cleanup checks.");
	}
	return 0;
}

#import "MBAudioNoteController.h"
#import <AVFoundation/AVFoundation.h>
#import "MBNote.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "NSError+Extras.h"

@interface MBAudioNoteWaveformView : NSView
@property (strong, nonatomic) NSMutableArray* levels;
- (void) appendLevel:(float)level;
@end

@implementation MBAudioNoteWaveformView

- (void) appendLevel:(float)level
{
	if (!self.levels) {
		self.levels = [NSMutableArray array];
	}
	[self.levels addObject:@(level)];
	if (self.levels.count > 100) {
		[self.levels removeObjectAtIndex:0];
	}
	self.needsDisplay = YES;
}

- (void) drawRect:(NSRect)dirtyRect
{
	NSBezierPath* background = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8];
	NSColor* background_color = [NSColor colorWithName:nil dynamicProvider:^NSColor* (NSAppearance* appearance) {
		NSString* match = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		if ([match isEqualToString:NSAppearanceNameDarkAqua]) {
			return [NSColor colorWithWhite:0.16 alpha:1];
		}
		return [NSColor colorWithSRGBRed:247.0 / 255 green:247.0 / 255 blue:247.0 / 255 alpha:1];
	}];
	[background_color setFill];
	[background fill];
	[NSGraphicsContext saveGraphicsState];
	[background addClip];
	[[NSColor controlAccentColor] setFill];
	CGFloat step = self.bounds.size.width / 100.0;
	for (NSInteger i = 0; i < 100; i++) {
		NSInteger index = i - (100 - self.levels.count);
		float level = index >= 0 ? [self.levels[index] floatValue] : 0;
		CGFloat height = MAX(2, sqrtf(level) * (self.bounds.size.height - 12));
		NSRect bar = NSMakeRect(i * step, (self.bounds.size.height - height) / 2, MAX(2, step - 2), height);
		[[NSBezierPath bezierPathWithRoundedRect:bar xRadius:1 yRadius:1] fill];
	}
	[NSGraphicsContext restoreGraphicsState];
}

@end

@interface MBAudioNoteController () <AVCaptureAudioDataOutputSampleBufferDelegate>
@property (strong, nonatomic) MBAudioNoteWaveformView* waveformView;
@property (strong, nonatomic) NSPopUpButton* inputsPopup;
@property (strong, nonatomic) NSButton* uploadButton;
@property (strong, nonatomic) NSTextField* statusField;
@property (strong, nonatomic) NSProgressIndicator* progressSpinner;
@property (weak, nonatomic) NSWindow* parentWindow;
@property (strong, nonatomic) NSNumber* notebookID;
@property (copy, nonatomic) NSString* secretKey;
@property (copy, nonatomic) NSString* username;
@property (copy, nonatomic) NSString* audioID;
@property (copy, nonatomic) NSString* transcript;
@property (copy, nonatomic) void (^completion)(MBNote* note, NSString* text, NSString* error);
@property (strong, nonatomic) NSURL* fileURL;
@property (strong, nonatomic) NSTimer* pollTimer;
@property (strong, nonatomic) NSDate* pollingStartedAt;
@property (assign, nonatomic) BOOL requestInFlight;
@property (assign, nonatomic) BOOL savingNote;
@property (assign, nonatomic) BOOL uploading;
@property (assign, nonatomic) BOOL finished;
@property (assign, atomic) BOOL cancelled;

// Capture session, writer and their state are used only on this serial queue.
@property (strong, nonatomic) dispatch_queue_t captureQueue;
@property (strong, nonatomic) AVCaptureSession* captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput* captureInput;
@property (strong, nonatomic) AVCaptureAudioDataOutput* captureOutput;
@property (strong, nonatomic) AVAssetWriter* writer;
@property (strong, nonatomic) AVAssetWriterInput* writerInput;
@property (assign, nonatomic) BOOL recording;
@property (assign, nonatomic) BOOL finishingFile;
@property (assign, nonatomic) CFAbsoluteTime lastWaveformUpdate;
@end

@implementation MBAudioNoteController

- (instancetype) initWithNotebookID:(NSNumber *)notebookID secretKey:(NSString *)secretKey completion:(void (^)(MBNote* note, NSString* text, NSString* error))handler
{
	self = [super initWithWindow:nil];
	if (self) {
		self.notebookID = notebookID;
		self.secretKey = secretKey;
		self.username = [RFSettings stringForKey:kAccountUsername];
		self.completion = handler;
		self.captureQueue = dispatch_queue_create("blog.micro.audio-note", DISPATCH_QUEUE_SERIAL);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancel:) name:kSignOutNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancel:) name:kSwitchAccountNotification object:nil];
	}
	return self;
}

- (void) loadWindow
{
	NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 240) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.title = @"Record Audio Note";
	window.releasedWhenClosed = NO;
	self.window = window;
	NSView* content = window.contentView;

	self.statusField = [NSTextField wrappingLabelWithString:@""];
	[self.statusField setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
	self.waveformView = [[MBAudioNoteWaveformView alloc] initWithFrame:NSZeroRect];
	self.waveformView.accessibilityLabel = @"Live microphone waveform";
	self.inputsPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	self.inputsPopup.target = self;
	self.inputsPopup.action = @selector(changeInput:);
	self.inputsPopup.enabled = NO;
	self.inputsPopup.accessibilityLabel = @"Microphone input";
	NSButton* cancel_button = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
	cancel_button.keyEquivalent = @"\e";
	self.uploadButton = [NSButton buttonWithTitle:@"Save Note" target:self action:@selector(upload:)];
	self.uploadButton.keyEquivalent = @"\r";
	self.uploadButton.enabled = NO;
	self.progressSpinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
	self.progressSpinner.style = NSProgressIndicatorStyleSpinning;
	self.progressSpinner.controlSize = NSControlSizeSmall;
	self.progressSpinner.displayedWhenStopped = NO;

	for (NSView* view in @[self.statusField, self.waveformView, self.inputsPopup, cancel_button, self.uploadButton, self.progressSpinner]) {
		view.translatesAutoresizingMaskIntoConstraints = NO;
		[content addSubview:view];
	}
	[NSLayoutConstraint activateConstraints:@[
		[self.statusField.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[self.statusField.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
		[self.statusField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
		[self.waveformView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[self.waveformView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
		[self.waveformView.topAnchor constraintEqualToAnchor:self.statusField.bottomAnchor constant:12],
		[self.waveformView.bottomAnchor constraintEqualToAnchor:self.inputsPopup.topAnchor constant:-20],
		[self.inputsPopup.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
		[self.inputsPopup.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20],
		[self.inputsPopup.widthAnchor constraintEqualToConstant:270],
		[self.uploadButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
		[self.uploadButton.centerYAnchor constraintEqualToAnchor:self.inputsPopup.centerYAnchor],
		[cancel_button.trailingAnchor constraintEqualToAnchor:self.uploadButton.leadingAnchor constant:-8],
		[cancel_button.centerYAnchor constraintEqualToAnchor:self.inputsPopup.centerYAnchor],
		[self.progressSpinner.trailingAnchor constraintEqualToAnchor:cancel_button.leadingAnchor constant:-12],
		[self.progressSpinner.centerYAnchor constraintEqualToAnchor:self.inputsPopup.centerYAnchor],
		[self.progressSpinner.widthAnchor constraintEqualToConstant:16],
		[self.progressSpinner.heightAnchor constraintEqualToConstant:16]
	]];
}

- (void) beginSheetForWindow:(NSWindow *)window
{
	// initWithWindow:nil does not trigger loadWindow automatically without a nib.
	if (!self.window) {
		[self loadWindow];
	}
	self.parentWindow = window;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancel:) name:NSWindowWillCloseNotification object:window];
	[window beginSheet:self.window completionHandler:nil];
	[self requestMicrophoneAccess];
}

- (void) requestMicrophoneAccess
{
	[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.finished) {
				return;
			}
			if (!granted) {
				[self showRecordingError:@"Allow microphone access for Micro.blog in System Settings → Privacy & Security → Microphone."];
				return;
			}
			[self startRecording];
		});
	}];
}

- (void) startRecording
{
	AVCaptureDeviceDiscoverySession* discovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeMicrophone, AVCaptureDeviceTypeExternal] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
	NSArray* devices = discovery.devices;
	AVCaptureDevice* default_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	for (AVCaptureDevice* device in devices) {
		[self.inputsPopup addItemWithTitle:device.localizedName];
		self.inputsPopup.lastItem.representedObject = device;
		if ([device.uniqueID isEqualToString:default_device.uniqueID]) {
			[self.inputsPopup selectItem:self.inputsPopup.lastItem];
		}
	}
	AVCaptureDevice* device = self.inputsPopup.selectedItem.representedObject;
	if (!device) {
		[self showRecordingError:@"No microphone input is available."];
		return;
	}
	NSString* filename = [NSString stringWithFormat:@"microblog-audio-%@.m4a", NSUUID.UUID.UUIDString];
	self.fileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:filename];

	dispatch_async(self.captureQueue, ^{
		if (self.cancelled) {
			return;
		}
		NSError* error = nil;
		self.captureSession = [[AVCaptureSession alloc] init];
		self.captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
		self.captureOutput = [[AVCaptureAudioDataOutput alloc] init];
		// Fixed PCM output makes metering predictable; the writer encodes compact mono AAC.
		self.captureOutput.audioSettings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @44100, AVNumberOfChannelsKey: @1, AVLinearPCMBitDepthKey: @32, AVLinearPCMIsFloatKey: @YES, AVLinearPCMIsNonInterleaved: @NO };
		if (!self.captureInput || ![self.captureSession canAddInput:self.captureInput] || ![self.captureSession canAddOutput:self.captureOutput]) {
			[self recordingFailed:error.localizedDescription ?: @"The microphone could not be started."];
			return;
		}
		[self.captureSession addInput:self.captureInput];
		[self.captureSession addOutput:self.captureOutput];
		[self.captureOutput setSampleBufferDelegate:self queue:self.captureQueue];
		self.writer = [[AVAssetWriter alloc] initWithURL:self.fileURL fileType:AVFileTypeAppleM4A error:&error];
		self.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:@{ AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @44100, AVNumberOfChannelsKey: @1, AVEncoderBitRateKey: @64000 }];
		self.writerInput.expectsMediaDataInRealTime = YES;
		if (!self.writer || ![self.writer canAddInput:self.writerInput]) {
			[self recordingFailed:error.localizedDescription ?: @"The audio file could not be created."];
			return;
		}
		[self.writer addInput:self.writerInput];
		self.recording = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureFailed:) name:AVCaptureSessionRuntimeErrorNotification object:self.captureSession];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureFailed:) name:AVCaptureSessionWasInterruptedNotification object:self.captureSession];
		[self.captureSession startRunning];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!self.finished && !self.uploading) {
				self.inputsPopup.enabled = YES;
				self.statusField.stringValue = @"Recording…";
			}
		});
	});
}

- (void) changeInput:(id)sender
{
	AVCaptureDevice* device = self.inputsPopup.selectedItem.representedObject;
	dispatch_async(self.captureQueue, ^{
		if (!self.recording || self.cancelled) {
			return;
		}
		NSError* error = nil;
		AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
		if (!input) {
			[self recordingFailed:error.localizedDescription ?: @"The microphone could not be selected."];
			return;
		}
		[self.captureSession beginConfiguration];
		[self.captureSession removeInput:self.captureInput];
		if ([self.captureSession canAddInput:input]) {
			[self.captureSession addInput:input];
			self.captureInput = input;
		}
		else {
			[self.captureSession addInput:self.captureInput];
			[self recordingFailed:@"The microphone could not be selected."];
		}
		[self.captureSession commitConfiguration];
	});
}

- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	if (!self.recording || self.cancelled || !CMSampleBufferDataIsReady(sampleBuffer)) {
		return;
	}
	if (self.writer.status == AVAssetWriterStatusFailed) {
		[self recordingFailed:self.writer.error.localizedDescription ?: @"Could not record audio."];
		return;
	}
	if (self.writer.status == AVAssetWriterStatusUnknown) {
		if (![self.writer startWriting]) {
			[self recordingFailed:self.writer.error.localizedDescription ?: @"Could not record audio."];
			return;
		}
		[self.writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!self.finished && !self.uploading) {
				self.uploadButton.enabled = YES;
			}
		});
	}
	if (self.writerInput.readyForMoreMediaData && ![self.writerInput appendSampleBuffer:sampleBuffer]) {
		[self recordingFailed:self.writer.error.localizedDescription ?: @"Could not record audio."];
		return;
	}
	if (CFAbsoluteTimeGetCurrent() - self.lastWaveformUpdate < 1.0 / 30.0) {
		return;
	}
	self.lastWaveformUpdate = CFAbsoluteTimeGetCurrent();
	AudioBufferList buffer_list;
	CMBlockBufferRef block_buffer = NULL;
	float peak = 0;
	OSStatus result = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &buffer_list, sizeof(buffer_list), NULL, NULL, 0, &block_buffer);
	if (result == noErr && buffer_list.mNumberBuffers == 1) {
		float* samples = buffer_list.mBuffers[0].mData;
		NSUInteger count = buffer_list.mBuffers[0].mDataByteSize / sizeof(float);
		for (NSUInteger i = 0; i < count; i++) {
			peak = MAX(peak, fabsf(samples[i]));
		}
	}
	if (block_buffer) {
		CFRelease(block_buffer);
	}
	float level = MIN(1, peak);
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!self.finished && !self.uploading) {
			[self.waveformView appendLevel:level];
		}
	});
}

- (void) captureFailed:(NSNotification *)notification
{
	dispatch_async(self.captureQueue, ^{
		[self recordingFailed:@"The microphone stopped recording. Please cancel and try again."];
	});
}

- (void) recordingFailed:(NSString *)message
{
	self.recording = NO;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!self.finished) {
			[self showRecordingError:message];
		}
	});
}

- (void) showRecordingError:(NSString *)message
{
	self.statusField.stringValue = message;
	self.uploadButton.enabled = NO;
	self.inputsPopup.enabled = NO;
	[self.progressSpinner stopAnimation:nil];
	dispatch_async(self.captureQueue, ^{
		self.recording = NO;
		[self.captureSession stopRunning];
	});
}

- (void) upload:(id)sender
{
	if (self.uploading || self.finished || !self.uploadButton.enabled) {
		return;
	}
	self.uploading = YES;
	self.uploadButton.enabled = NO;
	self.inputsPopup.enabled = NO;
	self.statusField.stringValue = @"Uploading…";
	[self.progressSpinner startAnimation:nil];
	dispatch_async(self.captureQueue, ^{
		self.recording = NO;
		[self.captureSession stopRunning];
		[self.captureOutput setSampleBufferDelegate:nil queue:NULL];
		if (self.cancelled) {
			return;
		}
		// A failed upload can be retried with this already finalized file.
		if (self.writer.status == AVAssetWriterStatusCompleted) {
			dispatch_async(dispatch_get_main_queue(), ^{ [self uploadRecordedFile]; });
			return;
		}
		if (self.writer.status != AVAssetWriterStatusWriting) {
			dispatch_async(dispatch_get_main_queue(), ^{ [self showRecordingError:@"No audio was recorded. Please cancel and try again."]; });
			return;
		}
		self.finishingFile = YES;
		[self.writerInput markAsFinished];
		[self.writer finishWritingWithCompletionHandler:^{
			dispatch_async(self.captureQueue, ^{
				self.finishingFile = NO;
				if (self.cancelled) {
					[self deleteTemporaryFile];
					return;
				}
				dispatch_async(dispatch_get_main_queue(), ^{
					if (self.writer.status == AVAssetWriterStatusCompleted) {
						[self uploadRecordedFile];
					}
					else {
						[self showRecordingError:self.writer.error.localizedDescription ?: @"The audio file could not be saved."];
					}
				});
			});
		}];
	});
}

- (BOOL) isCurrentAccount
{
	return self.username.length > 0 && [self.username isEqualToString:[RFSettings stringForKey:kAccountUsername]];
}

- (RFClient *) clientWithPath:(NSString *)path
{
	return [[RFClient alloc] initWithPath:path];
}

- (NSString *) errorForResponse:(UUHttpResponse *)response
{
	NSDictionary* result = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse : nil;
	NSString* message = result[@"error"];
	if ([message isKindOfClass:[NSString class]] && message.length > 0) {
		return message;
	}
	if (response.httpError) {
		return [response.httpError mb_networkMessageWithResponse:response.httpResponse];
	}
	return @"The server returned an unexpected response.";
}

- (BOOL) responseSucceeded:(UUHttpResponse *)response
{
	return !response.httpError && response.httpResponse.statusCode >= 200 && response.httpResponse.statusCode < 300;
}

- (void) uploadRecordedFile
{
	if (self.finished) {
		return;
	}
	if (![self isCurrentAccount]) {
		[self cancel:nil];
		return;
	}
	NSError* error = nil;
	NSData* data = [NSData dataWithContentsOfURL:self.fileURL options:NSDataReadingMappedIfSafe error:&error];
	if (data.length == 0 || data.length > 25 * 1024 * 1024) {
		[self showRecordingError:error.localizedDescription ?: @"The recording is empty or exceeds the 25 MB upload limit."];
		return;
	}
	RFClient* client = [self clientWithPath:@"/notes/audio"];
	[client uploadFileData:data named:@"file" filename:@"audio-note.m4a" contentType:@"audio/mp4" httpMethod:@"POST" queryArguments:nil completion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.finished) {
				return;
			}
			if (![self isCurrentAccount]) {
				[self cancel:nil];
				return;
			}
			NSDictionary* result = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse : nil;
			NSString* audio_id = result[@"id"];
			if (![self responseSucceeded:response] || ![audio_id isKindOfClass:[NSString class]] || audio_id.length == 0) {
				self.statusField.stringValue = [self errorForResponse:response];
				[self.progressSpinner stopAnimation:nil];
				self.uploading = NO;
				self.uploadButton.enabled = YES;
				return;
			}
			self.audioID = audio_id;
			[self dismissSheet];
			dispatch_async(self.captureQueue, ^{ [self deleteTemporaryFile]; });
			[self beginPolling];
		});
	}];
}

- (void) beginPolling
{
	if (self.finished || self.pollingStartedAt) {
		return;
	}
	self.pollingStartedAt = [NSDate date];
	void (^handler)(void) = self.processingStartedHandler;
	self.processingStartedHandler = nil;
	if (handler) {
		handler();
	}
	__weak MBAudioNoteController* weak_self = self;
	self.pollTimer = [NSTimer timerWithTimeInterval:2 repeats:YES block:^(NSTimer* timer) {
		[weak_self pollForTranscript];
	}];
	[[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}

- (BOOL) isProcessing
{
	return self.pollingStartedAt != nil && !self.finished;
}

- (void) pollForTranscript
{
	if (self.finished || self.savingNote || self.requestInFlight) {
		return;
	}
	if (![self isCurrentAccount]) {
		[self cancel:nil];
		return;
	}
	if (-self.pollingStartedAt.timeIntervalSinceNow > 15 * 60) {
		[self finishWithNote:nil error:@"Audio transcription timed out. Please try again later."];
		return;
	}
	self.requestInFlight = YES;
	[[self clientWithPath:@"/notes/audio"] getWithCompletion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.requestInFlight = NO;
			if (self.finished) {
				return;
			}
			if (![self isCurrentAccount]) {
				[self cancel:nil];
				return;
			}
			if (![self responseSucceeded:response]) {
				// Retry temporary network/server failures, but not authorization errors.
				if (response.httpResponse.statusCode == 401 || response.httpResponse.statusCode == 403) {
					[self finishWithNote:nil error:[self errorForResponse:response]];
				}
				return;
			}
			[self processTasksResponse:response.parsedResponse];
		});
	}];
}

- (void) processTasksResponse:(id)response
{
	if (self.finished || self.savingNote) {
		return;
	}
	NSArray* tasks = [response isKindOfClass:[NSDictionary class]] ? response[@"tasks"] : nil;
	if (![tasks isKindOfClass:[NSArray class]]) {
		[self finishWithNote:nil error:@"The server returned an unexpected audio status response."];
		return;
	}
	for (id task in tasks) {
		if (![task isKindOfClass:[NSDictionary class]] || ![self.audioID isEqual:task[@"id"]]) {
			continue;
		}
		if ([task[@"status"] isEqual:@"failed"]) {
			NSString* error = [task[@"error"] isKindOfClass:[NSString class]] ? task[@"error"] : @"The audio could not be transcribed.";
			[self finishWithNote:nil error:error];
		}
		else if ([task[@"status"] isEqual:@"completed"]) {
			NSString* text = task[@"text"];
			if (![text isKindOfClass:[NSString class]] || [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0) {
				[self finishWithNote:nil error:@"No text was returned for this recording."];
				return;
			}
			self.transcript = text;
			[self saveTranscribedNote];
		}
		return;
	}
}

- (void) saveTranscribedNote
{
	if (![self isCurrentAccount]) {
		[self cancel:nil];
		return;
	}
	[self.pollTimer invalidate];
	self.pollTimer = nil;
	self.savingNote = YES;
	NSString* encrypted_text = [MBNote encryptText:self.transcript withKey:self.secretKey];
	if (encrypted_text.length == 0) {
		[self finishWithNote:nil error:@"The transcript could not be encrypted. Check your notes key."];
		return;
	}
	NSDictionary* args = @{ @"text": encrypted_text, @"is_encrypted": @YES, @"notebook_id": self.notebookID };
	[[self clientWithPath:@"/notes"] postWithParams:args completion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.finished) {
				return;
			}
			if (![self isCurrentAccount]) {
				[self cancel:nil];
				return;
			}
			NSDictionary* result = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse : nil;
			NSNumber* note_id = result[@"id"];
			if (![self responseSucceeded:response] || ![note_id isKindOfClass:[NSNumber class]] || note_id.integerValue <= 0) {
				// Never automatically repeat this POST: the server may have saved it already.
				[self finishWithNote:nil error:[self errorForResponse:response]];
				return;
			}
			MBNote* note = [[MBNote alloc] init];
			note.noteID = note_id;
			note.notebookID = self.notebookID;
			note.text = self.transcript;
			note.isEncrypted = YES;
			note.createdAt = [NSDate date];
			note.updatedAt = note.createdAt;
			[self finishWithNote:note error:nil];
		});
	}];
}

- (void) dismissSheet
{
	[self.progressSpinner stopAnimation:nil];
	if (self.window.sheetParent) {
		[self.window.sheetParent endSheet:self.window];
	}
	[self.window orderOut:nil];
}

- (void) deleteTemporaryFile
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:self.captureSession];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:self.captureSession];
	// Release encoder/file handles promptly, rather than holding them while polling.
	self.writer = nil;
	self.writerInput = nil;
	self.captureInput = nil;
	self.captureOutput = nil;
	self.captureSession = nil;
	if (self.fileURL) {
		[[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
	}
}

- (void) cancel:(id)sender
{
	self.cancelled = YES;
	[self finishWithNote:nil error:nil];
}

- (void) finishWithNote:(MBNote *)note error:(NSString *)error
{
	if (self.finished) {
		return;
	}
	self.finished = YES;
	self.processingStartedHandler = nil;
	self.cancelled = YES;
	[self.pollTimer invalidate];
	self.pollTimer = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self dismissSheet];
	dispatch_async(self.captureQueue, ^{
		self.recording = NO;
		[self.captureSession stopRunning];
		[self.captureOutput setSampleBufferDelegate:nil queue:NULL];
		if (!self.finishingFile) {
			if (self.writer.status == AVAssetWriterStatusWriting || self.writer.status == AVAssetWriterStatusUnknown) {
				[self.writer cancelWriting];
			}
			[self deleteTemporaryFile];
		}
	});
	void (^handler)(MBNote*, NSString*, NSString*) = self.completion;
	self.completion = nil;
	if (handler) {
		handler(note, self.transcript, error);
	}
}

@end

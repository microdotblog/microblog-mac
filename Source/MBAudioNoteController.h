#import <Cocoa/Cocoa.h>

@class MBNote;

// Completion runs on the main thread. On a save failure, text contains the transcript
// so the caller can offer to copy it instead of losing the recording's contents.
@interface MBAudioNoteController : NSWindowController

@property (assign, nonatomic, readonly) BOOL isProcessing;
@property (copy, nonatomic) void (^processingStartedHandler)(void);

- (instancetype) initWithNotebookID:(NSNumber *)notebookID secretKey:(NSString *)secretKey completion:(void (^)(MBNote* note, NSString* text, NSString* error))handler;
- (void) beginSheetForWindow:(NSWindow *)window;
- (void) cancel:(id)sender;

@end

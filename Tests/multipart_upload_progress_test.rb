# Run with: ruby Tests/multipart_upload_progress_test.rb
# Send test multipart uploads only to a local server, using the production client
# methods and HTTP session. No Micro.blog account or external requests are used.
require 'tmpdir'
require 'socket'

root = File.expand_path('..', __dir__)
client = File.read(File.join(root, 'Source/RFClient.m'))
methods = %w[uploadImageData uploadFileData].map do |name|
	client[/^- \(UUHttpRequest \*\) #{name}:.*?^\}/m] or abort "Missing #{name}"
end.join("\n")
strings = File.read(File.join(root, 'Source/NSString+Extras.m'))
escape = strings[/^- \(NSString \*\) mb_escapedMultipartFilename.*?^\}/m] or abort 'Missing filename escaping'

source = <<~OBJC
	#import <Cocoa/Cocoa.h>
	#import "RFClient.h"
	@interface NSString (MultipartTest)
	- (NSString *) mb_escapedMultipartFilename;
	@end
	@implementation NSString (MultipartTest)
	#{escape}
	@end
	@implementation RFClient
	- (void) setupRequest:(UUHttpRequest *)request
	{
		NSMutableDictionary* headers = [request.headerFields mutableCopy];
		headers[@"Authorization"] = @"Token test-only";
		headers[@"User-Agent"] = @"Upload progress test";
		request.headerFields = headers;
	}
	#{methods}
	@end
	static void upload(NSString* base, NSString* path, BOOL image, BOOL progress, NSInteger status)
	{
		RFClient* client = [RFClient new];
		client.url = [base stringByAppendingString:path];
		NSData* data = [NSMutableData dataWithLength:8 * 1024 * 1024];
		__block int64_t sent = 0, expected = 0;
		__block NSInteger callbacks = 0;
		__block BOOL intermediate = NO;
		if (progress) {
			client.uploadProgressHandler = ^(int64_t bytes_sent, int64_t total_bytes) {
				NSCAssert(bytes_sent >= sent && bytes_sent <= total_bytes, @"Valid byte progress");
				sent = bytes_sent;
				expected = total_bytes;
				callbacks++;
				intermediate |= bytes_sent > 0 && bytes_sent < total_bytes;
			};
		}
		dispatch_semaphore_t done = dispatch_semaphore_create(0);
		void (^completion)(UUHttpResponse*) = ^(UUHttpResponse* response) {
			NSCAssert(response.httpResponse.statusCode == status, @"HTTP status preserved");
			NSCAssert([response.parsedResponse[@"ok"] boolValue] == (status == 201), @"JSON still parsed");
			NSCAssert((response.httpError != nil) == (status == 502), @"HTTP errors still reported");
			if (status == 201) {
				NSCAssert([response.httpResponse.allHeaderFields[@"Location"] isEqualToString:@"https://example.com/photo.jpg"], @"Upload Location retained");
			}
			dispatch_semaphore_signal(done);
		};
		NSDictionary* args = @{ @"mp-destination": @"test-site" };
		UUHttpRequest* request;
		if (image) {
			request = [client uploadImageData:data named:@"file" filename:@"photo.jpg" httpMethod:@"POST" queryArguments:args isVideo:NO isGIF:NO isPNG:NO completion:completion];
		}
		else {
			request = [client uploadFileData:data named:@"file" filename:@"photo.png" contentType:@"image/png" httpMethod:@"POST" queryArguments:args completion:completion];
		}
		NSCAssert(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0, @"Upload completed");
		if (progress) {
			NSCAssert(callbacks > 1 && intermediate && sent == expected, @"Real intermediate upload callbacks and 100 percent");
			NSCAssert(expected == request.body.length && expected > data.length, @"Progress measures the full multipart body");
		}
	}
	int main(int argc, const char* argv[])
	{
		@autoreleasepool {
			NSString* base = [NSString stringWithUTF8String:argv[1]];
			upload(base, @"/jpeg", YES, YES, 201);
			upload(base, @"/png", NO, YES, 201);
			upload(base, @"/legacy", YES, NO, 201);
			upload(base, @"/failure", NO, YES, 502);
			NSLog(@"Multipart upload byte-progress tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-upload-progress-') do |directory|
	path = File.join(directory, 'network.m')
	binary = File.join(directory, 'network')
	File.write(path, source)
	toolbox = File.join(root, 'Shared/UUToolbox')
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-mmacosx-version-min=14.0', '-Wno-incomplete-implementation', '-framework', 'Cocoa', '-I', File.join(root, 'Source'), '-I', toolbox, path, File.join(toolbox, 'UUHttpSession.m'), File.join(toolbox, 'UUHttpResponseHandler.m'), '-o', binary)

	server = TCPServer.new('127.0.0.1', 0)
	requests = []
	worker = Thread.new do
		4.times do
			socket = server.accept
			begin
				request_line = socket.gets("\r\n")
				headers = {}
				while (line = socket.gets("\r\n")) && line != "\r\n"
					key, value = line.strip.split(': ', 2)
					headers[key.downcase] = value
				end
				socket.write("HTTP/1.1 100 Continue\r\n\r\n") if headers['expect']&.downcase == '100-continue'
				body = +''.b
				length = Integer(headers.fetch('content-length'))
				while body.bytesize < length
					body << socket.read([65_536, length - body.bytesize].min)
					sleep 0.001 # Keep the body in flight long enough for intermediate callbacks.
				end
				requests << [request_line, headers, body]
				failure = request_line.include?('/failure ')
				json = failure ? '{"ok":false}' : '{"ok":true}'
				status = failure ? '502 Bad Gateway' : '201 Created'
				socket.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{json.bytesize}\r\nLocation: https://example.com/photo.jpg\r\nConnection: close\r\n\r\n#{json}")
			ensure
				socket.close
			end
		end
	end
	begin
		abort 'Network progress tests failed' unless system(binary, "http://127.0.0.1:#{server.addr[1]}")
		worker.value
		abort 'Each file must upload exactly once' unless requests.size == 4
		requests.each do |line, headers, body|
			abort 'Wrong method' unless line.start_with?('POST ')
			abort 'Lost request headers' unless headers['authorization'] == 'Token test-only' && headers['user-agent'] == 'Upload progress test'
			abort 'Not multipart' unless headers['content-type'].start_with?('multipart/form-data; boundary=')
			abort 'Lost destination' unless body.include?("name=\"mp-destination\"\r\n\r\ntest-site\r\n")
			abort 'Duplicate file part' unless body.scan('name="file"; filename=').size == 1
			mime = line.include?('/jpeg ') || line.include?('/legacy ') ? 'image/jpeg' : 'image/png'
			abort 'Lost MIME type' unless body.include?("Content-Type: #{mime}\r\n")
		end
	ensure
		worker.kill if worker.alive?
		server.close
	end
end

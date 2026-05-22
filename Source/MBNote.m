//
//  MBNote.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNote.h"

#import "SAMKeychain.h"
#import "SAMKeychain+Helper.h"
#import "Micro_blog-Swift.h"
#import "UUDate.h"

@implementation MBNote

- (id) copyWithZone:(NSZone *)zone
{
	MBNote* new_note = [[MBNote allocWithZone:zone] init];

	new_note.noteID = [self.noteID copyWithZone:zone];
	new_note.notebookID = [self.notebookID copyWithZone:zone];
	new_note.text = [self.text copyWithZone:zone];
	new_note.sharedURL = [self.sharedURL copyWithZone:zone];
	new_note.isEncrypted = self.isEncrypted;
	new_note.isShared = self.isShared;
	new_note.isSharing = self.isSharing;
	new_note.isUnsharing = self.isUnsharing;
	new_note.attachedBookISBN = [self.attachedBookISBN copyWithZone:zone];
	new_note.attachedBookTitle = [self.attachedBookTitle copyWithZone:zone];
	new_note.createdAt = [self.createdAt copyWithZone:zone];
	new_note.updatedAt = [self.updatedAt copyWithZone:zone];
	
	return new_note;
}

+ (BOOL) hasSecretKey
{
	NSString* s = [SAMKeychain mb_passwordForService:@"Micro.blog Notes" account:@""];
	return (s != nil);
}

+ (NSString *) cleanKey:(NSString *)key
{
	if ([key hasPrefix:@"mkey"]) {
		return [key substringFromIndex:4];
	}
	else {
		return key;
	}
}

+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)key
{
	NSData* key_data = [self dataFromHexString:key];

	// call to Swift wrapper
	MBNoteCrypto* crypto = [[MBNoteCrypto alloc] init];
	NSData* encrypted_data = [crypto encryptWithPlaintext:text key:key_data];
	
	// convert to base64 encoding
	NSString* s = [encrypted_data base64EncodedStringWithOptions:0];
	return s;
}

+ (NSString *) decryptText:(NSString *)text withKey:(NSString *)key
{
	if (text.length == 0) {
		return @"";
	}
	
	if ([text hasSuffix:@"\n"]) {
		text = [text substringToIndex:[text length] - 1];
	}
	
	NSData* key_data = [self dataFromHexString:key];
	NSData* decoded_data = [[NSData alloc] initWithBase64EncodedString:text options:0];

	// extract IV and tag from encrypted text
	NSInteger iv_size = 12;
	NSInteger tag_size = 16;
	NSData* iv = [decoded_data subdataWithRange:NSMakeRange(0, iv_size)];
	NSData* cipher_data = [decoded_data subdataWithRange:NSMakeRange(iv_size, decoded_data.length - iv_size)];
	NSData* tag = [cipher_data subdataWithRange:NSMakeRange(cipher_data.length - tag_size, tag_size)];

	// just get the encrypted data before the tag
	NSData* actual_cipher_data = [cipher_data subdataWithRange:NSMakeRange(0, cipher_data.length - tag_size)];
	
	// call to Swift wrapper
	MBNoteCrypto* crypto = [[MBNoteCrypto alloc] init];
	NSString* s = [crypto decryptWithEncryptedData:actual_cipher_data iv:iv tag:tag key:key_data];
			
	return s;
}

+ (NSData *) dataFromHexString:(NSString *)hexString
{
	NSMutableData* result = [[NSMutableData alloc] init];
	unsigned char whole_byte;
	char byte_chars[3] = { '\0','\0','\0' };

	for (int i = 0; i < [hexString length] / 2; i++) {
		byte_chars[0] = [hexString characterAtIndex:i*2];
		byte_chars[1] = [hexString characterAtIndex:i*2 + 1];
		whole_byte = strtol(byte_chars, NULL, 16);
		[result appendBytes:&whole_byte length:1];
	}

	return result;
}

+ (BOOL) isProbablyEncrypted:(NSString *)text
{
	BOOL result = NO;
	
	if (text.length > 30) {
		// if there are no spaces, probably encrypted
		NSString* s = [text substringToIndex:30];
		result = ![s containsString:@" "];
	}
		
	return result;
}

+ (MBNote *) noteWithDictionary:(NSDictionary *)dictionary notebookID:(NSNumber *)notebookID secretKey:(NSString *)secretKey
{
	NSDictionary* mb = [dictionary objectForKey:@"_microblog"];
	if (![mb isKindOfClass:[NSDictionary class]]) {
		mb = @{};
	}

	MBNote* note = [[MBNote alloc] init];

	note.noteID = [dictionary objectForKey:@"id"];
	note.isEncrypted = [[mb objectForKey:@"is_encrypted"] boolValue];
	note.isShared = [[mb objectForKey:@"is_shared"] boolValue];
	note.sharedURL = [mb objectForKey:@"shared_url"];
	note.attachedBookISBN = [mb objectForKey:@"attached_book_isbn"];
	note.attachedBookTitle = [mb objectForKey:@"attached_book_title"];
	note.notebookID = notebookID;

	NSString* text = [dictionary objectForKey:@"content_text"];
	if (note.isEncrypted) {
		note.text = [MBNote decryptText:text withKey:secretKey];
		if (note.text == nil) {
			// decryption probably failed
			note.text = @"";
		}
	}
	else {
		note.text = text;
	}

	NSString* created_s = [dictionary objectForKey:@"date_published"];
	note.createdAt = [NSDate uuDateFromRfc3339String:created_s];

	NSString* updated_s = [dictionary objectForKey:@"date_modified"];
	if (updated_s == nil) {
		updated_s = [dictionary objectForKey:@"date_updated"];
	}
	if (updated_s == nil) {
		updated_s = [mb objectForKey:@"updated_at"];
	}
	note.updatedAt = [NSDate uuDateFromRfc3339String:updated_s];
	if (note.updatedAt == nil) {
		note.updatedAt = note.createdAt;
	}

	return note;
}

@end

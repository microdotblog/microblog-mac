//
//  MBNote.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNote.h"

#import "Micro_blog-Swift.h"

@implementation MBNote

- (id) copyWithZone:(NSZone *)zone
{
	MBNote* new_note = [[MBNote allocWithZone:zone] init];

	new_note.noteID = [self.noteID copyWithZone:zone];
	new_note.text = [self.text copyWithZone:zone];
	new_note.isEncrypted = self.isEncrypted;
	new_note.isShared = self.isShared;
	new_note.createdAt = [self.createdAt copyWithZone:zone];
	new_note.updatedAt = [self.updatedAt copyWithZone:zone];
	
	return new_note;
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

@end

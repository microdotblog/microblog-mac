//
//  MBNoteCrypto.swift
//  Micro.blog
//
//  Created by Manton Reece on 12/12/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

import Foundation
import CryptoKit

@objc class MBNoteCrypto: NSObject {
	
	@objc func encrypt(plaintext: String, key: Data) -> Data? {
		let symmetric_key = SymmetricKey(data: key)
		let plaintext_data = Data(plaintext.utf8)

		do {
			let box = try AES.GCM.seal(plaintext_data, using: symmetric_key)
			return box.combined
		}
		catch {
			print("Encryption error: \(error)")
			return nil
		}
	}
	
	@objc func decrypt(encryptedData: Data, iv: Data, tag: Data, key: Data) -> String? {
		let symmetric_key = SymmetricKey(data: key)
		
		do {
			let nonce = try AES.GCM.Nonce(data: iv)
			let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData, tag: tag)
			let decrypted_data = try AES.GCM.open(box, using: symmetric_key)
			
			// convert decrypted data back to a string
			return String(data: decrypted_data, encoding: .utf8)
		} catch {
			print("Decryption error: \(error)")
			return nil
		}
	}
	
}

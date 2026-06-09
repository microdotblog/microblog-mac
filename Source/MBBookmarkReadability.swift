//
//  MBBookmarkReadability.swift
//  Micro.blog
//

import Foundation
import Readability

@objc(MBBookmarkReadability)
class MBBookmarkReadability: NSObject {
	@objc class func textContent(fromHTML html: String, baseURLString: String, completion: @escaping (String) -> Void) {
		Task { @MainActor in
			do {
				let baseURL = URL(string: baseURLString)
				let result = try await Readability().parse(html: html, options: nil, baseURL: baseURL)
				completion(result.textContent)
			}
			catch {
				NSLog("Bookmark readability parsing failed: \(error.localizedDescription)")
				completion("")
			}
		}
	}
}

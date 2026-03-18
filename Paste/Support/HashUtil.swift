//
//  HashUtil.swift
//  Paste
//
//  Content hashing utilities used for deduplication
//

import Foundation
import CryptoKit

enum HashUtil {
    
    /// Computes the SHA-256 hash of a string.
    static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        return sha256(data)
    }
    
    /// Computes the SHA-256 hash of a Data buffer.
    static func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes a hash of an array of file paths.
    static func sha256(filePaths: [String]) -> String {
        let combined = filePaths.sorted().joined(separator: "|")
        return sha256(combined)
    }
    
    /// Computes a hash of mixed content (used for composite clipboard items).
    static func sha256(text: String?, imageData: Data?, filePaths: [String]?) -> String {
        var combined = Data()
        
        if let text = text {
            combined.append(Data(text.utf8))
        }
        
        if let imageData = imageData {
            combined.append(imageData)
        }
        
        if let paths = filePaths, !paths.isEmpty {
            let pathString = paths.sorted().joined(separator: "|")
            combined.append(Data(pathString.utf8))
        }
        
        return sha256(combined)
    }
}

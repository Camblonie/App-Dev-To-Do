//
//  KeychainManager.swift
//  App Dev To-Do
//
//  Secure storage for GitHub Personal Access Token
//

import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidStatus(OSStatus)
    case conversionFailed
}

/// Manages secure storage of sensitive data in iOS Keychain
actor KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.scottcampbell.AppDevToDo"
    private let account = "github-pat"
    
    // MARK: - Token Operations
    
    /// Save GitHub Personal Access Token to Keychain
    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.conversionFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.invalidStatus(status)
        }
    }
    
    /// Retrieve GitHub Personal Access Token from Keychain
    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.invalidStatus(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionFailed
        }
        
        return token
    }
    
    /// Delete stored GitHub token from Keychain
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }
    }
    
    /// Check if token exists in Keychain
    func hasToken() -> Bool {
        do {
            return try getToken() != nil
        } catch {
            return false
        }
    }
}

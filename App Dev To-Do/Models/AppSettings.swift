//
//  AppSettings.swift
//  App Dev To-Do
//
//  Simple model for app settings stored in UserDefaults
//

import Foundation
import Combine

/// App settings that don't need secure storage
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let lastSyncDate = "lastSyncDate"
        static let selectedRepoOwner = "selectedRepoOwner"
        static let selectedRepoName = "selectedRepoName"
    }
    
    // MARK: - Properties
    
    var lastSyncDate: Date? {
        get { defaults.object(forKey: Keys.lastSyncDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSyncDate) }
    }
    
    var lastSelectedRepo: (owner: String, name: String)? {
        get {
            guard let owner = defaults.string(forKey: Keys.selectedRepoOwner),
                  let name = defaults.string(forKey: Keys.selectedRepoName) else {
                return nil
            }
            return (owner, name)
        }
        set {
            defaults.set(newValue?.owner, forKey: Keys.selectedRepoOwner)
            defaults.set(newValue?.name, forKey: Keys.selectedRepoName)
        }
    }
    
    // MARK: - Clear Settings
    
    func clearAllSettings() {
        defaults.removeObject(forKey: Keys.lastSyncDate)
        defaults.removeObject(forKey: Keys.selectedRepoOwner)
        defaults.removeObject(forKey: Keys.selectedRepoName)
    }
}

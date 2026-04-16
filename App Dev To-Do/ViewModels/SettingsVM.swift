//
//  SettingsVM.swift
//  App Dev To-Do
//
//  ViewModel for settings screen
//

import Foundation
import Combine
import SwiftData

@MainActor
class SettingsVM: ObservableObject {
    @Published var tokenInput = ""
    @Published var hasSavedToken = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var lastSyncDate: Date?
    
    init() {
        loadTokenStatus()
        lastSyncDate = AppSettings.shared.lastSyncDate
    }
    
    // MARK: - Token Management
    
    func loadTokenStatus() {
        Task {
            hasSavedToken = await KeychainManager.shared.hasToken()
        }
    }
    
    func saveToken() {
        guard !tokenInput.isEmpty else {
            errorMessage = "Please enter a token"
            showError = true
            return
        }
        
        // Validate token format (GitHub tokens are typically ghp_... or github_pat_...)
        let trimmedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSaving = true
        
        Task {
            do {
                try await KeychainManager.shared.saveToken(trimmedToken)
                hasSavedToken = true
                tokenInput = ""
                
                successMessage = "Token saved successfully!"
                showSuccess = true
            } catch {
                errorMessage = "Failed to save token: \(error.localizedDescription)"
                showError = true
            }
            
            isSaving = false
        }
    }
    
    func clearToken() {
        Task {
            do {
                try await KeychainManager.shared.deleteToken()
                hasSavedToken = false
                tokenInput = ""
                
                successMessage = "Token removed"
                showSuccess = true
            } catch {
                errorMessage = "Failed to remove token: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Token Creation URL
    
    var tokenCreationURL: URL {
        URL(string: "https://github.com/settings/tokens/new")!
    }
    
    // MARK: - Cache Management
    
    func clearCache(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Repository>()
        
        do {
            let repos = try modelContext.fetch(descriptor)
            repos.forEach { modelContext.delete($0) }
            try modelContext.save()
            
            AppSettings.shared.clearAllSettings()
            lastSyncDate = nil
            
            successMessage = "Cache cleared"
            showSuccess = true
        } catch {
            errorMessage = "Failed to clear cache: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Help Text
    
    let tokenInstructions = """
    To create a GitHub Personal Access Token:
    
    1. Tap "Create Token" to go to GitHub
    2. Click "Generate new token (classic)"
    3. Give it a name like "App Dev To-Do"
    4. Select the "repo" scope for full repository access
    5. Click "Generate token"
    6. Copy the token and paste it here
    
    The token is stored securely in your device's Keychain.
    """
}

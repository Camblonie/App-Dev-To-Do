//
//  RepositoryListVM.swift
//  App Dev To-Do
//
//  ViewModel for repository list screen
//

import Foundation
import SwiftData
import Combine

@MainActor
class RepositoryListVM: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var hasToken = false
    
    private var modelContext: ModelContext?
    
    var filteredRepositories: [Repository] {
        if searchText.isEmpty {
            return repositories
        }
        return repositories.filter { repo in
            repo.name.localizedCaseInsensitiveContains(searchText) ||
            repo.repoDescription?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCachedRepositories()
        checkTokenStatus()
    }
    
    // MARK: - Token Status
    
    func checkTokenStatus() {
        Task {
            hasToken = await KeychainManager.shared.hasToken()
        }
    }
    
    // MARK: - Data Loading
    
    func loadCachedRepositories() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Repository>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        
        do {
            repositories = try context.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load cached repositories: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func refreshRepositories() async {
        guard hasToken else {
            errorMessage = "Please add your GitHub token in Settings"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch from GitHub API
            let githubRepos = try await GitHubService.shared.fetchRepositories()
            
            // Convert to local models and check for TODO.md
            var localRepos: [Repository] = []
            for githubRepo in githubRepos {
                var repo = githubRepo.toLocalModel()
                
                // Check if TODO.md exists (don't block on this)
                do {
                    repo.hasTodoFile = try await GitHubService.shared.todoFileExists(
                        owner: repo.owner,
                        repo: repo.name
                    )
                } catch {
                    repo.hasTodoFile = nil
                }
                
                localRepos.append(repo)
            }
            
            // Update SwiftData
            guard let context = modelContext else { return }
            
            // Clear old data and insert new
            let descriptor = FetchDescriptor<Repository>()
            let existingRepos = try? context.fetch(descriptor)
            existingRepos?.forEach { context.delete($0) }
            
            for repo in localRepos {
                context.insert(repo)
            }
            
            try? context.save()
            
            // Update published properties
            repositories = localRepos
            
            // Update last sync date
            AppSettings.shared.lastSyncDate = Date()
            
        } catch let error as GitHubError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = "Failed to fetch repositories: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Repository Selection
    
    func selectRepository(_ repo: Repository) {
        AppSettings.shared.lastSelectedRepo = (repo.owner, repo.name)
    }
}

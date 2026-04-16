//
//  GitHubService.swift
//  App Dev To-Do
//
//  Handles all GitHub API interactions
//

import Foundation

enum GitHubError: Error, LocalizedError {
    case noToken
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case encodingError
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No GitHub token found. Please add your token in Settings."
        case .invalidURL:
            return "Invalid URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError:
            return "Failed to encode content."
        case .fileNotFound:
            return "TODO.md file not found."
        }
    }
}

/// GitHub API service for repository and file operations
actor GitHubService {
    static let shared = GitHubService()
    
    private let baseURL = "https://api.github.com"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication
    
    private func getAuthHeaders() async throws -> [String: String] {
        guard let token = try await KeychainManager.shared.getToken() else {
            throw GitHubError.noToken
        }
        return [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github.v3+json",
            "Content-Type": "application/json"
        ]
    }
    
    // MARK: - Repository Operations
    
    /// Fetch all repositories for the authenticated user
    func fetchRepositories() async throws -> [GitHubRepository] {
        let url = URL(string: "\(baseURL)/user/repos?sort=updated&direction=desc&per_page=100")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let headers = try await getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GitHubError.httpError(httpResponse.statusCode, message)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode([GitHubRepository].self, from: data)
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.networkError(error)
        }
    }
    
    // MARK: - File Operations
    
    /// Fetch TODO.md content from a repository
    func fetchTodoFile(owner: String, repo: String) async throws -> (content: String, sha: String) {
        let encodedPath = "TODO.md".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let headers = try await getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            throw GitHubError.fileNotFound
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.httpError(httpResponse.statusCode, message)
        }
        
        // GitHub returns content as base64 encoded
        struct FileResponse: Codable {
            let content: String
            let sha: String
        }
        
        let decoder = JSONDecoder()
        let fileResponse = try decoder.decode(FileResponse.self, from: data)
        
        // Decode base64 content (GitHub uses base64 with newlines)
        let cleanedContent = fileResponse.content.replacingOccurrences(of: "\n", with: "")
        guard let decodedData = Data(base64Encoded: cleanedContent),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            throw GitHubError.decodingError(NSError(domain: "Base64", code: -1))
        }
        
        return (decodedString, fileResponse.sha)
    }
    
    /// Create or update TODO.md file in a repository
    func saveTodoFile(owner: String, repo: String, content: String, sha: String? = nil) async throws {
        let encodedPath = "TODO.md".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let headers = try await getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Encode content to base64
        guard let contentData = content.data(using: .utf8) else {
            throw GitHubError.encodingError
        }
        let base64Content = contentData.base64EncodedString()
        
        // Build request body
        var body: [String: Any] = [
            "message": sha == nil ? "Create TODO.md" : "Update TODO.md",
            "content": base64Content
        ]
        
        // Include SHA if updating existing file
        if let sha = sha {
            body["sha"] = sha
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.httpError(httpResponse.statusCode, message)
        }
    }
    
    /// Append a new to-do item to an existing TODO.md file
    func appendTodoItem(owner: String, repo: String, item: TodoItem) async throws {
        // Try to fetch existing file
        var existingContent = ""
        var existingSha: String? = nil
        
        do {
            let (content, sha) = try await fetchTodoFile(owner: owner, repo: repo)
            existingContent = content
            existingSha = sha
        } catch GitHubError.fileNotFound {
            // File doesn't exist yet, start with empty content
            existingContent = "# App To-Do List\n\n"
        }
        
        // Parse existing content
        var todoFile = TodoFile.fromMarkdown(existingContent)
        todoFile.items.append(item)
        
        // Save updated content
        let newContent = todoFile.toMarkdown()
        try await saveTodoFile(owner: owner, repo: repo, content: newContent, sha: existingSha)
    }
    
    /// Check if TODO.md file exists in repository
    func todoFileExists(owner: String, repo: String) async throws -> Bool {
        do {
            _ = try await fetchTodoFile(owner: owner, repo: repo)
            return true
        } catch GitHubError.fileNotFound {
            return false
        }
    }
}

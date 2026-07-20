//
//  Repository.swift
//  App Dev To-Do
//
//  Model for caching GitHub repository information locally
//

import Foundation
import SwiftData

@Model
final class Repository {
    var id: Int
    var name: String
    var owner: String
    var repoDescription: String?
    var htmlUrl: String
    var isPrivate: Bool
    var lastUpdated: Date
    var lastSynced: Date
    var hasTodoFile: Bool?
    var pendingTodoCount: Int?
    
    init(
        id: Int,
        name: String,
        owner: String,
        repoDescription: String? = nil,
        htmlUrl: String,
        isPrivate: Bool,
        lastUpdated: Date,
        lastSynced: Date = Date(),
        hasTodoFile: Bool? = nil,
        pendingTodoCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.owner = owner
        self.repoDescription = repoDescription
        self.htmlUrl = htmlUrl
        self.isPrivate = isPrivate
        self.lastUpdated = lastUpdated
        self.lastSynced = lastSynced
        self.hasTodoFile = hasTodoFile
        self.pendingTodoCount = pendingTodoCount
    }
    
    /// Computed property for full repo identifier (owner/name)
    var fullName: String {
        "\(owner)/\(name)"
    }
}

// MARK: - GitHub API Response Model

struct GitHubRepository: Codable {
    let id: Int
    let name: String
    let owner: GitHubOwner
    let description: String?
    let htmlUrl: String
    let isPrivate: Bool
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, owner, description
        case htmlUrl = "html_url"
        case isPrivate = "private"
        case updatedAt = "updated_at"
    }
    
    struct GitHubOwner: Codable {
        let login: String
    }
    
    /// Convert API response to local SwiftData model
    func toLocalModel() -> Repository {
        let dateFormatter = ISO8601DateFormatter()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        
        return Repository(
            id: id,
            name: name,
            owner: owner.login,
            repoDescription: description,
            htmlUrl: htmlUrl,
            isPrivate: isPrivate,
            lastUpdated: updatedDate
        )
    }
}

//
//  TodoItem.swift
//  App Dev To-Do
//
//  Model representing a single to-do item
//

import Foundation

/// Represents a single task in a TODO.md file
@preconcurrency
struct TodoItem: Identifiable, Codable, Sendable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var createdAt: Date
    var priority: Priority?
    
    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        priority: Priority? = nil
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.priority = priority
    }
    
    enum Priority: String, Codable, CaseIterable, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}

// MARK: - Markdown Conversion

extension TodoItem {
    /// Convert to Markdown checkbox format
    nonisolated func toMarkdown() -> String {
        let checkbox = isCompleted ? "[x]" : "[ ]"
        let dateStr = createdAt.formatted(date: .abbreviated, time: .omitted)
        let priorityStr = priority.map { " [\($0.rawValue)]" } ?? ""
        return "- \(checkbox) \(text)\(priorityStr) - added \(dateStr)"
    }
    
    /// Create a TodoItem from a Markdown line
    nonisolated static func fromMarkdown(_ line: String) -> TodoItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- [") else { return nil }
        
        let isCompleted = trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
        
        // Remove checkbox prefix and parse the rest
        let content = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        
        // Extract date if present (pattern: " - added MM/DD/YY")
        let datePattern = /\ -\ added\ .+$/
        let textWithoutDate = content.replacing(datePattern, with: "")

        // Extract priority if present [High], [Medium], [Low]
        let priorityPattern = /\s*\[(High|Medium|Low)\]$/
        let priorityMatch = textWithoutDate.firstMatch(of: priorityPattern)
        let priority = priorityMatch.map { Priority(rawValue: String($0.1)) }
        let cleanText = textWithoutDate.replacing(priorityPattern, with: "").trimmingCharacters(in: .whitespaces)
        
        return TodoItem(
            text: cleanText,
            isCompleted: isCompleted,
            priority: priority ?? nil
        )
    }
}

// MARK: - TodoFile Container

/// Represents the entire TODO.md file content
@preconcurrency
struct TodoFile: Codable, Sendable {
    var items: [TodoItem]
    var header: String
    
    init(items: [TodoItem] = [], header: String = "# App To-Do List") {
        self.items = items
        self.header = header
    }
    
    /// Parse Markdown content into TodoFile
    nonisolated static func fromMarkdown(_ content: String) -> TodoFile {
        let lines = content.components(separatedBy: .newlines)
        var items: [TodoItem] = []
        var header = "# App To-Do List"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                header = trimmed
            } else if let item = TodoItem.fromMarkdown(line) {
                items.append(item)
            }
        }
        
        return TodoFile(items: items, header: header)
    }
    
    /// Convert to Markdown string for saving to GitHub
    nonisolated func toMarkdown() -> String {
        var lines = [header, ""]
        
        if items.isEmpty {
            lines.append("No tasks yet. Add your first to-do above!")
        } else {
            for item in items {
                lines.append(item.toMarkdown())
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

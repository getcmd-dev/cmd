//
//  RecentsEditsTracker2.swift
//  CodeCompletionService
//
//  Created by Guigui on 11/5/25.
//
import LoggingServiceInterface
import AppFoundation
import Foundation
import FileDiffFoundation

// TODO: check behavior between open and created

actor RecentsEditsTracker2: Sendable {
    init(diffBudget: Int, root: URL) {
        self.diffBudget = diffBudget
        self.root = root
    }
    private let root: URL
    private let diffBudget: Int
    /// The edit history of each file (ordered by file, most recent is last)
    private var filesEditsHistory: [URL: [FileVersion2]] = [:]
    /// The overall edit history (ordered by file, most recent is last)
    private var editsHistory: [FileVersion2] = []
    
    func process(updates: [(url: URL, content: String?)]) {
        for update in updates {
            var versions = filesEditsHistory[update.url]
            versions?.append(.init(url: update.url, content: update.content))
            filesEditsHistory[update.url] = versions
            
            editsHistory.append(.init(url: update.url, content: update.content))
        }
        
        var startIndex = 0
        while true {
            if startIndex >= editsHistory.count {
                break
            }
            do {
                let diff = try computeDiff(from: 0)
                if size(of: diff) > diffBudget {
                    startIndex += 1
                } else {
                    break
                }
            } catch {
                defaultLogger.error("Failed to compute diff for recent edits tracker", error)
                break
            }
        }
        discardsEdits(upTo: startIndex)
    }
    
    private func computeDiff(from idx: Int) throws -> String {
        var newContent = [URL: String?]()
        var beforeStateIdx = [URL: Int]()
        
        for edit in editsHistory[idx...] {
            newContent[edit.url] = newContent[edit.url, default: edit.content]
            beforeStateIdx[edit.url] = beforeStateIdx[edit.url, default: 0] + 1
        }
        var oldContent = [URL: String?]()
        for (url, count) in beforeStateIdx {
            if let fileHistory = filesEditsHistory[url] {
                if fileHistory.count > count {
                    oldContent[url] = fileHistory[fileHistory.count - count - 1].content
                } else if let content = fileHistory.first?.content{
                    oldContent[url] = content
                } else {
                    assertionFailure("File history too short for \(url.path)")
                    oldContent[url] = nil
                }
            } else {
                assertionFailure("File history missing for \(url.path)")
                oldContent[url] = nil
            }
        }
        
        return try FileDiff.getGitDiff(
            oldContent: Dictionary(uniqueKeysWithValues: oldContent.compactMapValues(\.self).map { k, v in (k.pathRelative(to: root), v) }),
            newContent: Dictionary(uniqueKeysWithValues: newContent.compactMapValues(\.self).map { k, v in (k.pathRelative(to: root), v) }))
    }
    
    private func size(of diff: String) -> Int {
        diff.split(separator: "\n").count
    }
    
    private func discardsEdits(upTo idx: Int) {
        var editsCount = [URL: Int]()
        for edit in editsHistory[..<idx] {
            editsCount[edit.url] = editsCount[edit.url, default: 0] + 1
        }
        for (url, count) in editsCount {
            if var fileHistory = filesEditsHistory[url] {
                if fileHistory.count >= count {
                    fileHistory.removeFirst(count)
                    filesEditsHistory[url] = fileHistory
                }
            }
        }
        editsHistory.removeFirst(idx)
    }
}

struct FileVersion2: Sendable {
    let url: URL
    let content: String?
}

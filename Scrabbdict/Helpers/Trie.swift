//
//  Trie.swift
//  Buckets
//
//  Created by Mauricio Santos on 2/26/15.
//  Copyright (c) 2015 Mauricio Santos. All rights reserved.
//

import Foundation

/// A Trie (sometimes called a prefix tree) is used for storing a set of
/// strings compactly and searching for words that can be formed from a set of letters.
///
/// This implementation is built once from a dictionary and then queried.
public struct Trie {
            
    // MARK: Creating a Trie

    /// Constructs a trie from a sequence, such as an array. Inserts all the elements
    /// from the given sequence into the trie.
    public init<S: Sequence>(_ elements: S) where S.Iterator.Element == String {
        for element in elements {
            _ = autoreleasepool {
                insertElement(element)
            }
        }
    }
    
    // MARK: Querying a Trie
    
    /// Number of words stored in the trie.
    public private(set) var count = 0
    
    /// Returns `true` if and only if `count == 0`.
    public var isEmpty: Bool {
        return count == 0
    }

    /// Returns all the words in the trie that can be formed from the given letters.
    public func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty else { return [] }

        var availableLetters = [UInt32: Int]()
        letters.unicodeScalars.forEach { availableLetters[$0.value, default: 0] += 1 }

        var currentWord = [Character]()
        var result = [String]()
        collectWords(from: rootIndex, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    @discardableResult
    private mutating func insertElement(_ word: String) -> Bool {
        if insert(word) {
            count += 1
            return true
        }
        return false
    }
    
    // MARK: Private Properties and Helper Methods
    
    /// The root node containing an empty word.
    fileprivate var nodes = [TrieNode()]

    private var rootIndex: TrieNodeIndex {
        0
    }
    
    private mutating func insert(_ word: String) -> Bool {
        var nodeIndex = rootIndex

        for scalar in word.unicodeScalars {
            nodeIndex = childIndex(for: scalar.value, in: nodeIndex)
        }

        let trieWasModified = nodes[Int(nodeIndex)].isWord != true
        nodes[Int(nodeIndex)].isWord = true
        return trieWasModified
    }

    private mutating func childIndex(for key: UInt32, in parentIndex: TrieNodeIndex) -> TrieNodeIndex {
        var childIndex = nodes[Int(parentIndex)].firstChild

        while childIndex != missingNodeIndex {
            if nodes[Int(childIndex)].key == key {
                return childIndex
            }
            childIndex = nodes[Int(childIndex)].nextSibling
        }

        let newChildIndex = TrieNodeIndex(nodes.count)
        nodes.append(TrieNode(key: key, nextSibling: nodes[Int(parentIndex)].firstChild))
        nodes[Int(parentIndex)].firstChild = newChildIndex
        return newChildIndex
    }

    private func collectWords(
        from nodeIndex: TrieNodeIndex,
        using availableLetters: inout [UInt32: Int],
        minLength: Int,
        currentWord: inout [Character],
        result: inout [String]
    ) {
        let node = nodes[Int(nodeIndex)]

        if node.isWord, currentWord.count >= minLength {
            result.append(String(currentWord))
        }

        var childIndex = node.firstChild

        while childIndex != missingNodeIndex {
            let child = nodes[Int(childIndex)]
            guard let remainingCount = availableLetters[child.key], remainingCount > 0 else {
                childIndex = child.nextSibling
                continue
            }

            availableLetters[child.key] = remainingCount - 1
            currentWord.append(Character(UnicodeScalar(child.key)!))
            collectWords(from: childIndex, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
            currentWord.removeLast()

            availableLetters[child.key] = remainingCount
            childIndex = child.nextSibling
        }
    }
}


// MARK: - TrieNode

private typealias TrieNodeIndex = Int32

private let missingNodeIndex: TrieNodeIndex = -1

private struct TrieNode {
    var key: UInt32
    var firstChild: TrieNodeIndex
    var nextSibling: TrieNodeIndex
    var isWord: Bool

    init(
        key: UInt32 = 0,
        firstChild: TrieNodeIndex = missingNodeIndex,
        nextSibling: TrieNodeIndex = missingNodeIndex,
        isWord: Bool = false
    ) {
        self.key = key
        self.firstChild = firstChild
        self.nextSibling = nextSibling
        self.isWord = isWord
    }
}

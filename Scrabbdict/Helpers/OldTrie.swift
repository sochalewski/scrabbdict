//
//  OldTrie.swift
//  ScrabbdictTests
//
//  Baseline copy of the original Trie implementation used for performance comparisons.
//

import Foundation

struct OldTrie {
    init() {}

    init<S: Sequence>(_ elements: S) where S.Iterator.Element == String {
        for element in elements {
            _ = autoreleasepool {
                insert(element)
            }
        }
    }

    private(set) var count = 0

    var isEmpty: Bool {
        return count == 0
    }

    var elements: [String] {
        var emptyGenerator = "".unicodeScalars.makeIterator()
        var result = [String]()
        var lastKeys = [Character]()
        result.reserveCapacity(count)
        findPrefix(&emptyGenerator, charStack: &lastKeys, result: &result, node: root)
        return result
    }

    func contains(_ word: String) -> Bool {
        var keys = word.unicodeScalars.makeIterator()
        let nodePair = nodePairForPrefix(&keys, node: root, parent: nil)
        return nodePair.endNode?.isWord ?? false
    }

    func isPrefix(_ prefix: String) -> Bool {
        var keys = prefix.unicodeScalars.makeIterator()
        let nodePair = nodePairForPrefix(&keys, node: root, parent: nil)
        return nodePair.endNode != nil
    }

    func findPrefix(_ prefix: String) -> [String] {
        var prefixKeys = prefix.unicodeScalars.makeIterator()
        var result = [String]()
        var lastKeys = [Character]()
        findPrefix(&prefixKeys, charStack: &lastKeys, result: &result, node: root)
        return result
    }

    func findPattern(_ pattern: String) -> [String] {
        let prefixKeys = pattern.unicodeScalars.makeIterator()
        var result = [String]()
        var lastKeys = [Character]()
        findPattern(prefixKeys, charStack: &lastKeys, result: &result, node: root)
        return result
    }

    func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty else { return [] }

        var availableLetters = [UnicodeScalar: Int]()
        letters.unicodeScalars.forEach { availableLetters[$0, default: 0] += 1 }

        var currentWord = [Character]()
        var result = [String]()
        collectWords(from: root, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    func longestPrefixIn(_ element: String) -> String {
        var keys = element.unicodeScalars.makeIterator()
        return longestPrefixIn(&keys, lastChars: [], node: root)
    }

    @discardableResult
    mutating func insert(_ word: String) -> Bool {
        if !contains(word) {
            copyMyself()
            var keyGenerator = word.unicodeScalars.makeIterator()
            if insert(&keyGenerator, node: root) {
                count += 1
                return true
            }
        }
        return false
    }

    @discardableResult
    mutating func remove(_ word: String) -> String? {
        if contains(word) {
            copyMyself()
            var generator = word.unicodeScalars.makeIterator()
            let nodePair = nodePairForPrefix(&generator, node: root, parent: nil)

            if let elementNode = nodePair.endNode, elementNode.isWord {
                elementNode.isWord = false
                if let parentNode = nodePair.parent, let key = elementNode.key, elementNode.children.isEmpty {
                    parentNode.children.removeValue(forKey: key)
                }
                count -= 1
                return word
            }
        }
        return nil
    }

    mutating func removeAll() {
        root = OldTrieNode(key: nil)
        count = 0
    }

    fileprivate var root = OldTrieNode(key: nil)

    private func nodePairForPrefix(_ charGenerator: inout String.UnicodeScalarView.Iterator,
                                   node: OldTrieNode,
                                   parent: OldTrieNode?) -> (endNode: OldTrieNode?, parent: OldTrieNode?) {
        let nextChar: UnicodeScalar! = charGenerator.next()
        if nextChar == nil {
            return (node, parent)
        }

        if let nextNode = node.children[nextChar] {
            return nodePairForPrefix(&charGenerator, node: nextNode, parent: node)
        } else {
            return (nil, node)
        }
    }

    private func findPrefix(_ prefixGenerator: inout String.UnicodeScalarView.Iterator,
                            charStack: inout [Character],
                            result: inout [String],
                            node: OldTrieNode) {
        if let key = node.key?.escaped(asASCII: false) {
            charStack.append(Character(key))
        }
        if let theKey = prefixGenerator.next() {
            if let nextNode = node.children[theKey] {
                findPrefix(&prefixGenerator, charStack: &charStack, result: &result, node: nextNode)
            }
        } else {
            if node.isWord {
                result.append(String(charStack))
            }
            node.children.values.forEach {
                findPrefix(&prefixGenerator, charStack: &charStack, result: &result, node: $0)
            }
        }
        if node.key != nil {
            charStack.removeLast()
        }
    }

    private func findPattern(_ prefixGenerator: String.UnicodeScalarView.Iterator,
                             charStack: inout [Character],
                             result: inout [String],
                             node: OldTrieNode) {
        if let key = node.key?.escaped(asASCII: false) {
            charStack.append(Character(key))
        }
        var myPrefixGenerator = prefixGenerator
        if let theKey = myPrefixGenerator.next() {
            if let nextNode = node.children[theKey] {
                findPattern(myPrefixGenerator, charStack: &charStack, result: &result, node: nextNode)
            } else if "\(theKey)" == "?" {
                node.children.values.forEach {
                    findPattern(myPrefixGenerator, charStack: &charStack, result: &result, node: $0)
                }
            }
        } else {
            if node.isWord {
                result.append(String(charStack))
            }
        }
        if node.key != nil {
            charStack.removeLast()
        }
    }

    private func longestPrefixIn(_ keyGenerator: inout String.UnicodeScalarView.Iterator,
                                 lastChars: [Character],
                                 node: OldTrieNode) -> String {
        let chars: [Character]
        if let key = node.key {
            chars = lastChars + [Character(key.escaped(asASCII: false))]
        } else {
            chars = lastChars
        }
        if let theKey = keyGenerator.next(), let nextNode = node.children[theKey] {
            return longestPrefixIn(&keyGenerator, lastChars: chars, node: nextNode)
        }
        return String(chars)
    }

    private func insert(_ keyGenerator: inout String.UnicodeScalarView.Iterator, node: OldTrieNode) -> Bool {
        if let nextKey = keyGenerator.next() {
            let nextNode = node.children[nextKey] ?? OldTrieNode(key: nextKey)
            node.children[nextKey] = nextNode
            return insert(&keyGenerator, node: nextNode)
        } else {
            let trieWasModified = node.isWord != true
            node.isWord = true
            return trieWasModified
        }
    }

    private mutating func copyMyself() {
        if !isKnownUniquelyReferenced(&root) {
            root = deepCopyNode(root)
        }
    }

    private func deepCopyNode(_ node: OldTrieNode) -> OldTrieNode {
        let copy = OldTrieNode(key: node.key, isWord: node.isWord)
        for (key, subNode) in node.children {
            copy.children[key] = deepCopyNode(subNode)
        }
        return copy
    }

    private func collectWords(from node: OldTrieNode,
                              using availableLetters: inout [UnicodeScalar: Int],
                              minLength: Int,
                              currentWord: inout [Character],
                              result: inout [String]) {
        if node.isWord, currentWord.count >= minLength {
            result.append(String(currentWord))
        }

        for (letter, childNode) in node.children {
            guard let remainingCount = availableLetters[letter], remainingCount > 0 else { continue }

            availableLetters[letter] = remainingCount - 1
            currentWord.append(Character(letter.escaped(asASCII: false)))
            collectWords(from: childNode, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
            currentWord.removeLast()

            availableLetters[letter] = remainingCount
        }
    }
}

extension OldTrie: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        return "[" + elements.map { "\($0)" }.joined(separator: ", ") + "]"
    }

    var debugDescription: String {
        return description
    }
}

extension OldTrie: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(root)
    }
}

func ==(lhs: OldTrie, rhs: OldTrie) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    return lhs.root == rhs.root
}

private final class OldTrieNode: Equatable, Hashable {
    let key: UnicodeScalar?
    var isWord: Bool = false
    var children = [UnicodeScalar: OldTrieNode]()

    init(key: UnicodeScalar?, isWord: Bool = false) {
        self.key = key
        self.isWord = isWord
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(isWord)
        hasher.combine(key?.hashValue ?? 0)
        for (_, subnode) in children {
            hasher.combine(subnode)
        }
    }
}

private func ==(lhs: OldTrieNode, rhs: OldTrieNode) -> Bool {
    if lhs.key != rhs.key || lhs.isWord != rhs.isWord || lhs.children.count != rhs.children.count {
        return false
    }
    for (key, leftNode) in lhs.children {
        if leftNode != rhs.children[key] {
            return false
        }
    }
    return true
}

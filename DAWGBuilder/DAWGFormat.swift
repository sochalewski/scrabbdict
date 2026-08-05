//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

/// DAWG v5 is an edge-only encoding: there is no node table.
/// A node is identified by the index of its first outgoing edge,
/// and each edge is a single little-endian `UInt32`:
///
/// - bits 0-21: target (first-edge index of the child node, `0` = no outgoing edges),
/// - bit 22: word flag (the path ending with this edge spells a word),
/// - bit 23: last flag (this is the last outgoing edge of its source node),
/// - bits 24-31: alphabet index of the edge label.
///
/// The alphabet table preceding the edge table stores distinct `UInt16`
/// Unicode scalars in the localized order selected by the generator.
/// Scalar value breaks localized comparison ties, making the table order
/// deterministic. This ordering is part of the format contract, not merely a
/// generator implementation detail.
///
/// A node's outgoing edges are stored consecutively and sorted by ascending
/// alphabet index, so a reader can stop scanning a node as soon as it sees
/// a key greater than the one it is looking for.
///
/// Together, the ordered alphabet and edge blocks make depth-first enumeration
/// ascending in the alphabet order encoded by the dictionary.
///
/// The root node's edges start at index `0`. Because the graph is acyclic,
/// no edge can target the root, so `0` is unambiguous as the null target.
enum DAWGFormat {
    static let magic: UInt32 = 0x47574453
    static let version: UInt32 = 5
    static let headerSize = 20
    static let edgeSize = 4
    static let edgeTargetMask: UInt32 = 0x003f_ffff
    static let edgeWordFlag: UInt32 = 0x0040_0000
    static let edgeLastFlag: UInt32 = 0x0080_0000
    static let edgeKeyShift = 24
}

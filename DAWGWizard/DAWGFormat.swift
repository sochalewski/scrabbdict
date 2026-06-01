//
//  DAWGWizard
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

enum DAWGFormat {
    static let magic: UInt32 = 0x47574453
    static let version: UInt32 = 3
    static let headerSize = 24
    static let nodeSize = 6
    static let edgeSize = 4
    static let wordFlag: UInt16 = 0x8000
    static let packedEdgeCountMask: UInt16 = 0x7fff
}

internal enum RefinementArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(RefinementError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(RefinementError) -> T {
        do throws(FlexibleError) { return try body() } catch { throw .flexible(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(RefinementError) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(RefinementError) -> Double {
        guard value.isFinite else { throw .nonFinite }; return value
    }
    static func check(_ p: RefinementPolicy) throws(RefinementError) {
        guard !Task.isCancelled, !p.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ p: RefinementPolicy, _ work: inout NumericalWork) throws(RefinementError) {
        try check(p); try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func text(_ value: String, _ p: RefinementPolicy, _ work: inout NumericalWork) throws(RefinementError) {
        var count = 0
        for _ in value.utf8 {
            guard count < p.maximumIdentifierBytes else { throw .capacityExceeded }
            try charge(1,p,&work); count += 1
        }
        guard count > 0 else { throw .invalidInput }
    }
    static func product(_ a: Int, _ b: Int) throws(RefinementError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(RefinementError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) }
    }
    static func storage(_ count: Int, _ p: RefinementPolicy, _ work: inout NumericalWork) throws(RefinementError) {
        guard count <= p.maximumScalars else { throw .capacityExceeded }
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func identifier(_ start: UInt64, offset: Int) throws(RefinementError) -> UInt64 {
        guard offset >= 0, let converted = UInt64(exactly: offset) else { throw .identifierOverflow }
        let (value, overflow) = start.addingReportingOverflow(converted)
        guard !overflow else { throw .identifierOverflow }; return value
    }
    static func midpoint(_ a: Vector3, _ b: Vector3) throws(RefinementError) -> Vector3 {
        try core { () throws(CoreError) in try a.scaled(by: 0.5).adding(b.scaled(by: 0.5)) }
    }
    static func volume(_ points: [Vector3], _ nodes: [Int]) throws(RefinementError) -> Double {
        try finite(core { () throws(CoreError) in
            try points[nodes[1]].subtracting(points[nodes[0]]).dot(points[nodes[2]].subtracting(points[nodes[0]]).cross(points[nodes[3]].subtracting(points[nodes[0]])))
        } / 6)
    }
    static func referenceVolume(_ nodes: [FlexibleNode], _ indices: [Int]) throws(RefinementError) -> Double {
        let p = nodes[indices[0]].referencePosition
        return try finite(core { () throws(CoreError) in
            try nodes[indices[1]].referencePosition.subtracting(p).dot(nodes[indices[2]].referencePosition.subtracting(p).cross(nodes[indices[3]].referencePosition.subtracting(p)))
        } / 6)
    }
    static func faceAreaVector(_ nodes: [FlexibleNode], _ indices: [Int]) throws(RefinementError) -> Vector3 {
        let origin = nodes[indices[0]].referencePosition
        return try core { () throws(CoreError) in
            try nodes[indices[1]].referencePosition.subtracting(origin).cross(nodes[indices[2]].referencePosition.subtracting(origin))
        }
    }
    static func edge(_ a: Int, _ b: Int, nodes: [FlexibleNode]) -> RefinementEdge {
        if nodes[a].identifier < nodes[b].identifier {
            return RefinementEdge(lowerIdentifier: nodes[a].identifier, upperIdentifier: nodes[b].identifier, lowerNode: a, upperNode: b)
        }
        return RefinementEdge(lowerIdentifier: nodes[b].identifier, upperIdentifier: nodes[a].identifier, lowerNode: b, upperNode: a)
    }
    static func edgeLess(_ a: RefinementEdge, _ b: RefinementEdge) -> Bool {
        a.lowerIdentifier < b.lowerIdentifier || (a.lowerIdentifier == b.lowerIdentifier && a.upperIdentifier < b.upperIdentifier)
    }
    static func sameFace(_ a: [Int], _ b: [Int]) -> Bool {
        a.count == 3 && b.count == 3 && a.allSatisfy { b.contains($0) }
    }
    static func oppositeFace(_ a: [Int], _ b: [Int]) -> Bool {
        (0..<3).contains { b[$0] == a[0] && b[($0+1)%3] == a[2] && b[($0+2)%3] == a[1] }
    }
    static func sameOrientation(_ a: [Int], _ b: [Int]) -> Bool {
        (0..<3).contains { b[$0] == a[0] && b[($0+1)%3] == a[1] && b[($0+2)%3] == a[2] }
    }
}

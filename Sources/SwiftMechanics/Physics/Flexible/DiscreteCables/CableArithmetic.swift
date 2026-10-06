internal enum CableArithmetic {
    static func check(_ policy: CablePolicy) throws(CableError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func finite(_ value: Double) throws(CableError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(CableError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(CableError) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(CableError) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func sum(_ a: Int, _ b: Int) throws(CableError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) }
    }
    static func product(_ a: Int, _ b: Int) throws(CableError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) }
    }
    static func component(_ vector: Vector3, _ axis: Int) -> Double {
        axis == 0 ? vector.x : axis == 1 ? vector.y : vector.z
    }
    static func add(_ a: Vector3, _ b: Vector3) throws(CableError) -> Vector3 {
        try core { () throws(CoreError) in try a.adding(b) }
    }
    static func subtract(_ a: Vector3, _ b: Vector3) throws(CableError) -> Vector3 {
        try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func scale(_ a: Vector3, _ scalar: Double) throws(CableError) -> Vector3 {
        try core { () throws(CoreError) in try a.scaled(by: scalar) }
    }
    static func dot(_ a: Vector3, _ b: Vector3) throws(CableError) -> Double {
        try core { () throws(CoreError) in try a.dot(b) }
    }
    static func cross(_ a: Vector3, _ b: Vector3) throws(CableError) -> Vector3 {
        try core { () throws(CoreError) in try a.cross(b) }
    }
    static func norm(_ a: Vector3) throws(CableError) -> Double {
        try core { () throws(CoreError) in try a.magnitude() }
    }
    static func segmentLength(_ edge: Vector3, minimum: Double, segment: Int) throws(CableError) -> Double {
        // Identical scalar evaluation order to the analytic jet norm makes an undeformed
        // tension-only segment exactly the nonsmooth branch, even on a non-axis-aligned mesh.
        let scale = max(abs(edge.x),max(abs(edge.y),abs(edge.z)))
        guard scale > 0 else { throw .degenerateSegment(index: segment) }
        var squared = 0.0
        for axis in 0..<3 { let x = component(edge,axis)/scale; squared += x*x }
        let length = try finite(squared.squareRoot()*scale)
        guard length >= minimum else { throw .degenerateSegment(index: segment) }
        return length
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(CableError) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x,y,z) }
    }
    static func reserve(_ nodes: Int, _ work: inout NumericalWork) throws(CableError) {
        // Includes simultaneous element jets, additive tangent blocks, result/input arrays,
        // and the evolving call's old/new assemblies and immutable transactional records.
        let count = try sum(8192, product(nodes, 512))
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func metadata(_ cable: DiscreteCable, state: NodalState, policy: CablePolicy,
                         work: inout NumericalWork) throws(CableError) {
        let strings = [cable.frame.key, state.frame.key, cable.source.source,
                       cable.material.identifier.key, cable.material.source.source]
        var bytes = 0
        for string in strings {
            try check(policy)
            // UTF-8 count can require traversal: bound and charge before identifier equality.
            for _ in string.utf8 {
                try check(policy)
                guard bytes < policy.maximumMetadataBytes else { throw .capacityExceeded }
                try charge(1, &work); bytes += 1
            }
        }
    }
}

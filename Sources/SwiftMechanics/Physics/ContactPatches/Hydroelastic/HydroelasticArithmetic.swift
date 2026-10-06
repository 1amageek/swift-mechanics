internal enum HydroelasticArithmetic {
    static func check(_ policy: HydroelasticPolicy) throws(HydroelasticError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(HydroelasticError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ a: Int, _ b: Int, _ work: inout NumericalWork) throws(HydroelasticError) {
        do { try work.requireStorage(NumericalWork.sum(1024,NumericalWork.product(20,NumericalWork.sum(a,b)))) }
        catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(HydroelasticError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func core<T>(_ body: () throws(CoreError) -> T, _ work: inout NumericalWork) throws(HydroelasticError) -> T {
        // Every public fixed-sized Core primitive receives a conservative scalar-operation charge.
        try charge(100,&work); do { return try body() } catch { throw .core(error) }
    }
    static func add(_ a: Vector3,_ b: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 { try core({ () throws(CoreError) in try a.adding(b) },&work) }
    static func sub(_ a: Vector3,_ b: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 { try core({ () throws(CoreError) in try a.subtracting(b) },&work) }
    static func scale(_ a: Vector3,_ b: Double,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 { try core({ () throws(CoreError) in try a.scaled(by:b) },&work) }
    static func dot(_ a: Vector3,_ b: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Double { try core({ () throws(CoreError) in try a.dot(b) },&work) }
    static func cross(_ a: Vector3,_ b: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Vector3 { try core({ () throws(CoreError) in try a.cross(b) },&work) }
    static func norm(_ a: Vector3,_ work: inout NumericalWork) throws(HydroelasticError) -> Double { try core({ () throws(CoreError) in try a.magnitude() },&work) }
    static func bytes(_ value: String,_ policy: HydroelasticPolicy,_ work: inout NumericalWork) throws(HydroelasticError) {
        var iterator=value.utf8.makeIterator(), count=0
        while true {
            try check(policy); try charge(2,&work)
            guard iterator.next() != nil else { break }
            guard count < policy.maximumMetadataBytes else { throw .capacityExceeded }; count+=1
        }
    }
    static func same(_ a: EntityID,_ b: EntityID,_ policy: HydroelasticPolicy,_ work: inout NumericalWork) throws(HydroelasticError) -> Bool {
        try bytes(a.key,policy,&work); try bytes(b.key,policy,&work); try charge(1,&work); return a == b
    }
    static func same(_ a: SourceProvenance,_ b: SourceProvenance,_ policy: HydroelasticPolicy,_ work: inout NumericalWork) throws(HydroelasticError) -> Bool {
        try bytes(a.source,policy,&work); try bytes(b.source,policy,&work); try charge(1,&work); return a == b
    }
}

internal enum StructuralArithmetic {
    static func num<T>(_ body: () throws(NumericalError) -> T) throws(StructuralError) -> T { do { return try body() } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) } }
    static func check(_ policy: StructuralPolicy) throws(StructuralError) { guard !policy.isCancelled(),!Task.isCancelled else { throw .cancelled } }
    static func finite(_ value: Double) throws(StructuralError) -> Double { guard value.isFinite else { throw .nonFiniteResult };return value }
    static func size(_ a: Int,_ b: Int) throws(StructuralError) -> Int { try num { () throws(NumericalError) in try NumericalWork.product(a,b) } }
    static func sum(_ a: Int,_ b: Int) throws(StructuralError) -> Int { try num { () throws(NumericalError) in try NumericalWork.sum(a,b) } }
    static func charge(_ count: Int,_ work: inout NumericalWork) throws(StructuralError) { try num { () throws(NumericalError) in try work.chargeOperations(count) } }
    static func reserve(_ count: Int,_ work: inout NumericalWork) throws(StructuralError) { try num { () throws(NumericalError) in try work.requireStorage(count) } }
    static func metadata(_ identity: String,_ frame: String,policy: StructuralPolicy) throws(StructuralError) {
        guard !identity.isEmpty,try sum(identity.utf8.count,frame.utf8.count) <= policy.maximumMetadataBytes else { throw .capacityExceeded }
    }
    static func bindingStorage(_ binding: StructuralBinding) throws(StructuralError) -> Int {
        let model=try sum(binding.beam == nil ? 0 : 32,try size(16,binding.equilibriumModel?.chart.count ?? 0))
        return try sum(model,try sum(try size(3,binding.retainedCoordinates.count),try sum(binding.sourceCoordinateIDs.count,try sum(binding.reductionBasis.count,binding.operatingCoordinates.count))))
    }
    static func validate(_ pencil: StructuralPencil,expected: StructuralBinding,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) {
        try check(policy);try metadata(pencil.binding.identity,pencil.binding.frame.key,policy:policy)
        let n=pencil.count,nn=try size(n,n)
        guard n>0,n<=policy.maximumCoordinates,pencil.mass.count==nn,pencil.stiffness.count==nn,pencil.damping.count==nn,
            pencil.binding.coordinateScales.count==n,pencil.binding.dimensions.count==n,pencil.binding.operatingCoordinates.count<=policy.maximumCoordinates,
            expected.retainedCoordinates.count==n,expected.coordinateScales.count==n,expected.dimensions.count==n,expected.operatingCoordinates.count<=policy.maximumCoordinates else { throw .capacityExceeded }
        guard pencil.binding.sourceCoordinateIDs.count<=policy.maximumCoordinates,expected.sourceCoordinateIDs.count<=policy.maximumCoordinates,
            pencil.binding.reductionBasis.count <= (try size(policy.maximumCoordinates,policy.maximumCoordinates)),
            expected.reductionBasis.count <= (try size(policy.maximumCoordinates,policy.maximumCoordinates)) else { throw .capacityExceeded }
        let actualBytes=try sum(try sum(pencil.binding.identity.utf8.count,pencil.binding.frame.key.utf8.count),pencil.binding.provenance?.source.utf8.count ?? 0)
        let expectedBytes=try sum(try sum(expected.identity.utf8.count,expected.frame.key.utf8.count),expected.provenance?.source.utf8.count ?? 0)
        guard actualBytes<=policy.maximumMetadataBytes,expectedBytes<=policy.maximumMetadataBytes else { throw .capacityExceeded }
        for pair in 0..<2 {
            let binding=pair==0 ? pencil.binding : expected
            if let beam=binding.beam { guard try size(2,try sum(beam.elements,1))<=policy.maximumCoordinates else { throw .capacityExceeded } }
            if let model=binding.equilibriumModel {
                guard model.chart.count<=policy.maximumCoordinates else { throw .capacityExceeded }
                var bytes=try sum(pair==0 ? actualBytes : expectedBytes,try sum(model.identity.utf8.count,try sum(model.parameterIdentity.utf8.count,binding.branchIdentity?.utf8.count ?? 0)))
                for joint in model.chart.joints { bytes=try sum(bytes,joint.key.utf8.count) }
                guard bytes<=policy.maximumMetadataBytes else { throw .capacityExceeded }
                try charge(bytes,&work)
            }
        }
        try metadata(expected.identity,expected.frame.key,policy:policy)
        guard pencil.binding==expected else { throw .staleBinding }
        for i in 0..<n {
            try check(policy);try charge(try size(8,n),&work)
            guard pencil.binding.coordinateScales[i].isFinite,pencil.binding.coordinateScales[i]>0 else { throw .invalidInput }
            for j in 0..<n {
                let ij=i*n+j,ji=j*n+i
                guard pencil.mass[ij].isFinite,pencil.stiffness[ij].isFinite,pencil.damping[ij].isFinite else { throw .invalidInput }
                guard pencil.mass[ij]==pencil.mass[ji],pencil.stiffness[ij]==pencil.stiffness[ji],pencil.damping[ij]==pencil.damping[ji] else { throw .nonsymmetric }
            }
        }
    }
}

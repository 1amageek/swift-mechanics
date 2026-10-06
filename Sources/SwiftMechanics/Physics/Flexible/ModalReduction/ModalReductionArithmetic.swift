internal enum ModalReductionArithmetic {
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ModalReductionError) -> T {
        do { return try body() } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ModalReductionError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func size(_ a: Int, _ b: Int) throws(ModalReductionError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(ModalReductionError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(ModalReductionError) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func reserve(_ count: Int, _ work: inout NumericalWork) throws(ModalReductionError) {
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func finite(_ value: Double) throws(ModalReductionError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func check(_ policy: ModalReductionPolicy) throws(ModalReductionError) {
        guard !Task.isCancelled, !policy.structural.isCancelled() else { throw .cancelled }
    }
    static func structural<T>(reservedStorage: Int, work: inout NumericalWork,
                              _ body: (inout NumericalWork) throws(StructuralError) -> T) throws(ModalReductionError) -> T {
        let budget=try numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reservedStorage) }
        var supplier=NumericalWork(budget:budget)
        let value:T
        do { value=try body(&supplier) }
        catch {
            // Structural suppliers expose their consumed caller-owned work even on failure.
            try numerical { () throws(NumericalError) in try work.absorb(supplier,reservedStorage:reservedStorage) }
            throw .structural(error)
        }
        try numerical { () throws(NumericalError) in try work.absorb(supplier,reservedStorage:reservedStorage) }
        return value
    }
    static func product(_ a: [Double], rows: Int, inner: Int, _ b: [Double], columns: Int,
                        policy: ModalReductionPolicy, work: inout NumericalWork) throws(ModalReductionError) -> [Double] {
        guard a.count == (try size(rows,inner)), b.count == (try size(inner,columns)) else { throw .invalidInput }
        var result=[Double](repeating:0,count:try size(rows,columns))
        for i in 0..<rows {
            try check(policy); try charge(try size(try size(2,inner),columns),&work)
            for j in 0..<columns {
                var value=0.0
                for k in 0..<inner { value=try finite(value+a[i*inner+k]*b[k*columns+j]) }
                result[i*columns+j]=value
            }
        }
        return result
    }
    static func transpose(_ a: [Double], rows: Int, columns: Int,
                          policy: ModalReductionPolicy, work: inout NumericalWork) throws(ModalReductionError) -> [Double] {
        guard a.count == (try size(rows,columns)) else { throw .invalidInput }
        var result=[Double](repeating:0,count:a.count)
        for i in 0..<rows { try check(policy); try charge(columns,&work)
            for j in 0..<columns { result[j*rows+i]=a[i*columns+j] }
        }
        return result
    }
    static func effortDimension(_ coordinate: PhysicalDimension) throws(ModalReductionError) -> PhysicalDimension {
        func subtract(_ a: Int8, _ b: Int8) throws(ModalReductionError) -> Int8 {
            let (value,overflow)=a.subtractingReportingOverflow(b)
            guard !overflow else { throw .dimensionMismatch }; return value
        }
        let e=PhysicalDimension.energy
        return try PhysicalDimension(length:subtract(e.length,coordinate.length),mass:subtract(e.mass,coordinate.mass),
            time:subtract(e.time,coordinate.time),angle:subtract(e.angle,coordinate.angle),
            electricCurrent:subtract(e.electricCurrent,coordinate.electricCurrent),temperature:subtract(e.temperature,coordinate.temperature),
            amount:subtract(e.amount,coordinate.amount),luminousIntensity:subtract(e.luminousIntensity,coordinate.luminousIntensity))
    }
    static func storage(_ model: ModalReducedModel) throws(ModalReductionError) -> Int {
        let n=model.pencil.count, r=model.count, full=model.fullCoordinateCount
        let maps=try sum(model.maps.inputMap.count,model.maps.interfaceMap.count)
        let matrix=try sum(try size(6,try size(n,n)),try size(12,try size(r,r)))
        let vectors=try sum(try size(20,full),try size(8,try size(n,r)))
        let metadata=try sum(try size(12,maps),try size(16,try sum(model.maps.inputDimensions.count,model.maps.interfaceDimensions.count)))
        return try sum(model.tetrahedra?.scalarStorage ?? 64,try sum(matrix,try sum(vectors,metadata)))
    }
    static func binding(_ candidate: StructuralBinding, matches model: ModalReducedModel,
                        work: inout NumericalWork) throws(ModalReductionError) {
        let n=model.pencil.count,full=model.fullCoordinateCount
        guard candidate.source==model.pencil.binding.source,candidate.equilibriumModel==nil,
              candidate.reductionBasis.isEmpty,candidate.retainedCoordinates.count==n,
              candidate.dimensions.count==n,candidate.coordinateScales.count==n,
              candidate.operatingCoordinates.count<=full,candidate.sourceCoordinateIDs.count<=full else { throw .staleBinding }
        var bytes=try sum(candidate.identity.utf8.count,candidate.frame.key.utf8.count)
        bytes=try sum(bytes,candidate.provenance?.source.utf8.count ?? 0)
        bytes=try sum(bytes,candidate.branchIdentity?.utf8.count ?? 0)
        if let beam=candidate.beam {
            bytes=try sum(bytes,try sum(beam.identity.utf8.count,beam.source.source.utf8.count))
        }
        guard bytes<=model.policy.structural.maximumMetadataBytes else { throw .capacityExceeded }
        try charge(try sum(bytes,try size(16,full)),&work)
        guard candidate==model.pencil.binding else { throw .staleBinding }
    }
}

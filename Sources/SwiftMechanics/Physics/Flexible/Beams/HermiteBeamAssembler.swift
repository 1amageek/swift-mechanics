public struct HermiteBeamAssembler: BeamAssembling, Sendable {
    public init() {}
    @inline(never)
    public func assemble(_ beam: UniformBeam, admission: BeamAdmission, work: inout NumericalWork) throws(BeamError) -> BeamAssembly {
        try check(admission)
        guard beam.elements <= admission.maximumElements else { throw .capacityExceeded }
        let lengths=[beam.identity.utf8.count,beam.frame.key.utf8.count,beam.source.source.utf8.count]
        var bytes=0
        for value in lengths { bytes=try num { () throws(NumericalError) in try NumericalWork.sum(bytes,value) } }
        guard bytes <= admission.maximumMetadataBytes else { throw .capacityExceeded }
        let n=try num { () throws(NumericalError) in try NumericalWork.product(2,try NumericalWork.sum(beam.elements,1)) }
        let nn=try num { () throws(NumericalError) in try NumericalWork.product(n,n) }
        try num { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(80,try NumericalWork.product(4,nn))) }
        let e=try finite(9/(3/beam.elasticity.shearModulus+1/beam.elasticity.bulkModulus))
        let h=try finite(beam.length/Double(beam.elements)),h2=try finite(h*h),h3=try finite(h2*h)
        guard e > 0, h > 0, h2 > 0, h3 > 0 else { throw .nonFiniteResult }
        let k=try finite(e*beam.secondMoment/h3),g=try finite(1/(30*h)),m=try finite(beam.density*beam.area*h/420)
        guard k > 0,g > 0,m > 0 else { throw .nonFiniteResult }
        let ke=[12.0,6*h,-12,6*h, 6*h,4*h2,-6*h,2*h2, -12,-6*h,12,-6*h, 6*h,2*h2,-6*h,4*h2]
        let ge=[36.0,3*h,-36,3*h, 3*h,4*h2,-3*h,-h2, -36,-3*h,36,-3*h, 3*h,-h2,-3*h,4*h2]
        let me=[156.0,22*h,54,-13*h, 22*h,4*h2,13*h,-3*h2, 54,13*h,156,-22*h, -13*h,-3*h2,-22*h,4*h2]
        var stiffness=[Double](repeating:0,count:nn),geometric=stiffness,mass=stiffness,damping=stiffness
        try num { () throws(NumericalError) in try work.chargeOperations(80) }
        for cell in 0..<beam.elements {
            try check(admission)
            try num { () throws(NumericalError) in try work.chargeOperations(96) }
            for i in 0..<4 { for j in 0..<4 {
                let index=(2*cell+i)*n+2*cell+j,local=4*i+j
                stiffness[index]=try finite(stiffness[index]+k*ke[local])
                geometric[index]=try finite(geometric[index]+g*ge[local])
                mass[index]=try finite(mass[index]+m*me[local])
            } }
        }
        for i in 0..<n {
            try check(admission)
            try num { () throws(NumericalError) in try work.chargeOperations(3*n) }
            for j in 0..<n { let index=i*n+j;damping[index]=try finite(beam.massDamping*mass[index]+beam.stiffnessDamping*stiffness[index]) }
        }
        try check(admission)
        return BeamAssembly(beam:beam,youngModulus:e,coordinateCount:n,elasticStiffness:stiffness,geometricStiffness:geometric,mass:mass,damping:damping)
    }
    private func check(_ admission: BeamAdmission) throws(BeamError) { guard !admission.isCancelled(), !Task.isCancelled else { throw .cancelled } }
    private func finite(_ value: Double) throws(BeamError) -> Double { guard value.isFinite else { throw .nonFiniteResult };return value }
    private func num<T>(_ body: () throws(NumericalError) -> T) throws(BeamError) -> T { do { return try body() } catch { throw .numerical(error) } }
}

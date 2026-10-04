/// Sealed original spatial covectors, or explicitly reduced planar covectors, for continuous-force coupling.
/// Original dependent rows remain represented; this witness does not certify unique physical allocation.
public final class GeometricPhysicalRowWitness: Sendable {
    public enum Convention: Equatable, Sendable { case continuousForceEnergyCovector }
    public enum Fidelity: Equatable, Sendable { case spatialBodyPointCovectors, reducedPlanarBodyPointCovectors }
    public let fidelity: Fidelity
    public let convention: Convention = .continuousForceEnergyCovector
    public let model: ModelStamp
    public let dimension: KinematicDimension
    public let metadata: String
    public let original: HolonomicGeometrySample
    public let rows: [GeometricPhysicalRow]
    public let maximumProjectionResidual: Double
    private init(system: GeometricConstraintSystem, original: HolonomicGeometrySample, rows: [GeometricPhysicalRow], residual: Double) {
        let admittedDimension = system.model.tree.bodies[0].dimension
        model = system.model.stamp; dimension = admittedDimension; metadata = system.metadata
        fidelity = admittedDimension == .planar ? .reducedPlanarBodyPointCovectors : .spatialBodyPointCovectors
        self.original = original; self.rows = rows; maximumProjectionResidual = residual
    }
    internal static func make(_ system: GeometricConstraintSystem, state: KinematicState, supplied: HolonomicGeometrySample,
                              policy: GeometricPhysicalRowPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> GeometricPhysicalRowWitness {
        try GeometricArithmetic.check(policy.evaluation)
        let count = system.model.tree.bodies.count, n = system.layout.scales.count, m = system.rowIDs.count
        guard count <= policy.maximumBodies, m <= policy.evaluation.maximumRows, n <= policy.evaluation.maximumCoordinates else { throw .capacityExceeded }
        guard supplied.source == state, supplied.metadata == system.metadata else { throw .staleSource }
        let admission = try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.product(128,NumericalWork.product(m,NumericalWork.sum(count,1)))
        }
        try GeometricArithmetic.charge(admission,&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Time-dependent target work, nonzero coincidence targets and prescribed/static endpoint support authority are not admitted by this physical-output port. Existing kinematic evaluation remains available; output must fail until the additional physical support contract is proved.
        for relation in system.relations {
            try GeometricArithmetic.check(policy.evaluation)
            guard !relation.target.isExplicitTime,
                  relation.kind != .coincidence || relation.target.value == .zero,
                  relation.first.body != relation.second.body else { throw .unsupportedPhysicalRows }
            for endpoint in [relation.first, relation.second] {
                guard system.model.descriptor.bodies.first(where: { $0.id == endpoint.body })?.mode == .dynamic,
                      !GeometricConstraintSystem.isPrescribed(endpoint,tree:system.model.tree) else { throw .unsupportedPhysicalRows }
            }
        }
        let reserve = try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            let width = try NumericalWork.sum(n,1)
            return try NumericalWork.sum(system.scalarStorage, NumericalWork.sum(NumericalWork.product(1024,NumericalWork.product(count,width)),NumericalWork.product(128,NumericalWork.product(m,width))))
        }
        try GeometricArithmetic.numeric { () throws(NumericalError) in try work.requireStorage(reserve) }
        let original = try GeometricOriginalAcceptance.validatedSample(supplied,system:system,state:state,
            tolerance:policy.originalComparisonTolerance,policy:policy.evaluation,work:&work)
        var rows: [GeometricPhysicalRow] = []; rows.reserveCapacity(m)
        var maximum = 0.0, rowIndex = 0
        for (relationIndex, relation) in system.relations.enumerated() {
            try GeometricArithmetic.check(policy.evaluation)
            let charge = try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.product(4096,NumericalWork.sum(n,1)) }
            try GeometricArithmetic.charge(charge,&work)
            let a = try GeometricEndpointMotion.make(relation.first,snapshot:original.snapshot,original:true)
            let b = try GeometricEndpointMotion.make(relation.second,snapshot:original.snapshot,original:true)
            for component in relation.rowIDs.indices {
                try GeometricArithmetic.check(policy.evaluation)
                let zero = system.model.tree.bodies[0].dimension == .planar && relation.kind == .coincidence && component == 2
                let gradient: (Vector3,Vector3) = try GeometricArithmetic.geometry {
                    switch relation.kind {
                    case .coincidence:
                        let axis: Vector3 = zero ? .zero : (component == 0 ? .unitX : (component == 1 ? .unitY : .unitZ))
                        return (try axis.scaled(by:1/relation.scale),.zero)
                    case .distance:
                        // Divide sequentially to avoid overflowing scale^2 while preserving the original normalization.
                        return (try a.point.subtracting(b.point).scaled(by:1/relation.scale).scaled(by:1/relation.scale),.zero)
                    case .alignedAxes:
                        let local = component == 0 ? relation.transverseFirst : relation.transverseSecond
                        let basis = try GeometricDirectionMotion.make(relation.second,frameDirection:local,snapshot:original.snapshot)
                        return (.zero,try a.axis.cross(basis.direction))
                    }
                }
                let first = GeometricRowEndpointCovector(body:relation.first.body,worldFrame:system.model.tree.worldFrame,point:a.point,linear:gradient.0,angular:gradient.1)
                let second = try GeometricArithmetic.geometry {
                    GeometricRowEndpointCovector(body:relation.second.body,worldFrame:system.model.tree.worldFrame,point:b.point,
                        linear:try gradient.0.scaled(by:-1),angular:try gradient.1.scaled(by:-1))
                }
                let row = GeometricPhysicalRow(rowID:relation.rowIDs[component],relationIndex:relationIndex,componentIndex:component,kind:relation.kind,
                    normalizationScale:relation.scale,isStructuralZero:zero,first:first,second:second)
                for j in 0..<n {
                    try GeometricArithmetic.check(policy.evaluation); try GeometricArithmetic.charge(128,&work)
                    let projected = try projection(first,snapshot:original.snapshot,column:j) + projection(second,snapshot:original.snapshot,column:j)
                    let expected = original.velocity.rows[rowIndex*n+j]/system.layout.scales[j]
                    let error = try GeometricArithmetic.finite(projected-expected)
                    guard try GeometricArithmetic.geometry({ try policy.projectionTolerance.contains(error:error,scale:max(abs(projected),abs(expected))) }) else {
                        throw .originalRejected(row:row.rowID)
                    }
                    maximum = max(maximum,abs(error))
                }
                rows.append(row); rowIndex += 1
            }
        }
        try GeometricArithmetic.check(policy.evaluation)
        return GeometricPhysicalRowWitness(system:system,original:original,rows:rows,residual:maximum)
    }
    private static func projection(_ endpoint: GeometricRowEndpointCovector, snapshot: KinematicSnapshot, column: Int) throws(GeometricConstraintError) -> Double {
        try GeometricArithmetic.geometry {
            let state = try snapshot.body(endpoint.body), columns = try snapshot.geometricColumns(body:endpoint.body)
            let value = columns[columns.startIndex+column], offset = try endpoint.referencePointWorld.subtracting(state.motion.pose.translation)
            return try endpoint.linearGradient.dot(value.linear.adding(value.angular.cross(offset))) + endpoint.angularGradient.dot(value.angular)
        }
    }
}

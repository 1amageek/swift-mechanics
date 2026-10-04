/// Immutable equation authority bound to an actual spatial compiled tree.
public struct GeometricConstraintSystem: Sendable {
    public let model: CompiledMechanicalModel
    public let layout: ConstraintCoordinateLayout
    public let relations: [GeometricRelation]
    public let rowIDs: [UInt64]
    public let minimumPosition: [Double]
    public let maximumPosition: [Double]
    public let minimumTime: Double
    public let maximumTime: Double
    public let metadata: String
    public let scalarStorage: Int
    public let prescribedMotion:PrescribedMotionProgram?
    public var isExplicitTime: Bool { prescribedMotion != nil || relations.contains { $0.target.isExplicitTime } }
    public init(model:CompiledMechanicalModel,layout:ConstraintCoordinateLayout,relations:[GeometricRelation],
                minimumPosition:[Double],maximumPosition:[Double],minimumTime:Double,maximumTime:Double,
                capacity:GeometricConstraintCapacity,work:inout NumericalWork,prescribedMotion:PrescribedMotionProgram? = nil) throws(GeometricConstraintError) {
        let tree=model.tree,p=tree.layout.positionCount,n=tree.layout.velocityCount,b=tree.bodies.count
        guard b <= capacity.maximumBodies,p <= capacity.maximumPositions,n > 0,n <= capacity.maximumVelocities,
              !relations.isEmpty,relations.count <= capacity.maximumRows else { throw .capacityExceeded }
        guard layout.scales.count == n,layout.revision == model.stamp.revision,
              minimumPosition.count == p,maximumPosition.count == p,minimumTime.isFinite,maximumTime.isFinite,minimumTime <= maximumTime else { throw .invalidShape }
        var m=0
        for relation in relations { m=try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.sum(m,relation.rowIDs.count) } }
        guard m <= capacity.maximumRows else { throw .capacityExceeded }
        let storage=try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.sum(try NumericalWork.product(256,try NumericalWork.product(b,n+1)),
                try NumericalWork.sum(try NumericalWork.product(16,try NumericalWork.product(m,n+1)),try NumericalWork.product(16,p+n)))
        }
        try GeometricArithmetic.numeric { () throws(NumericalError) -> Void in try work.requireStorage(storage) }
        let admissionWork=try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.product(8,try NumericalWork.sum(try NumericalWork.product(n,n),try NumericalWork.sum(try NumericalWork.product(m,m),
                try NumericalWork.sum(try NumericalWork.product(b,m),try NumericalWork.sum(b+p+n,m)))))
        }
        try GeometricArithmetic.charge(admissionWork,&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar/disconnected and fully prescribed floating-root partitions require independent physical and coordinate authority evidence. This path admits spatial connected trees and fixed-root prescribed parent-anchor bases only.
        guard tree.bodies.allSatisfy({$0.dimension == .spatial}) else { throw .unsupportedDomain }
        try GeometricPrescribedBinding.validate(model,program:prescribedMotion,work:&work)
        for i in 0..<p { guard minimumPosition[i].isFinite,maximumPosition[i].isFinite,minimumPosition[i] <= maximumPosition[i] else { throw .invalidInput } }
        for i in 0..<n {
            guard layout.scales[i].isFinite,layout.scales[i] > 0,!layout.coordinateIDs[..<i].contains(layout.coordinateIDs[i]) else { throw .invalidInput }
        }
        var expected:[PhysicalDimension]=[];expected.reserveCapacity(n)
        switch tree.rootBase {
        case .fixed: break
        case .planarFloating: expected += [.length,.length,.angle]
        case .spatialFloating: expected += [.length,.length,.length,.angle,.angle,.angle]
        }
        for joint in tree.joints {
            switch joint.manifold.kind {
            case .spherical: expected += [.angle,.angle,.angle]
            case .sixDOF: expected += [.length,.length,.length,.angle,.angle,.angle]
            default: for axis in joint.manifold.orderedAxes { expected.append(axis.kind == .prismatic ? .length : .angle) }
            }
        }
        guard expected == layout.dimensions else { throw .invalidInput }
        var ids:[UInt64]=[];ids.reserveCapacity(m)
        for relation in relations {
            for id in relation.rowIDs { guard !ids.contains(id) else { throw .invalidInput };ids.append(id) }
            _=try Self.resolve(relation.first,tree:tree);_=try Self.resolve(relation.second,tree:tree)
        }
        if let program=prescribedMotion {
            do throws(PrescribedMotionError) {
                let source=model.descriptor.initialState
                let supplied=try PrescribedMotionSample(metadata:program.metadata,time:source.time,anchors:source.prescribedAnchors,policy:program.policy)
                _=try OriginalPrescribedMotionAcceptance.validated(supplied,program:program,time:source.time,policy:program.policy,work:&work)
            } catch { throw .motion(error) }
        }
        let metadata=try GeometricMetadata.encode(model:model,layout:layout,relations:relations,minimum:minimumPosition,maximum:maximumPosition,
            minimumTime:minimumTime,maximumTime:maximumTime,limit:capacity.maximumMetadataBytes,work:&work,prescribedMotion:prescribedMotion)
        self.prescribedMotion=prescribedMotion;self.model=model;self.layout=layout;self.relations=relations;rowIDs=ids;self.minimumPosition=minimumPosition
        self.maximumPosition=maximumPosition;self.minimumTime=minimumTime;self.maximumTime=maximumTime;self.metadata=metadata;scalarStorage=try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.sum(storage,metadata.utf8.count/8+1) }
    }
    internal static func resolve(_ endpoint:GeometricFrameEndpoint,tree:KinematicTree) throws(GeometricConstraintError) -> RigidTransform {
        guard let body=tree.bodies.first(where:{$0.id == endpoint.body}) else { throw .staleSource }
        if body.frame == endpoint.frame { return .identity }
        for joint in tree.joints {
            if joint.parentBody == endpoint.body,joint.parentAnchor.frame == endpoint.frame {
                switch joint.parentAnchor.placement { case .fixed(let pose): return pose; case .prescribed: return .identity }
            }
            if joint.childBody == endpoint.body,joint.childAnchor.frame == endpoint.frame,case .fixed(let pose)=joint.childAnchor.placement { return pose }
        }
        throw .staleSource
    }
    internal func snapshot(_ state:KinematicState,policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(GeometricConstraintError) -> KinematicSnapshot {
        try GeometricArithmetic.check(policy)
        guard policy.expectedLayoutRevision == layout.revision,state.revision == layout.revision else { throw .staleSource }
        guard state.q.count == model.tree.layout.positionCount,state.v.count == layout.scales.count,
              state.acceleration.count == state.v.count,
              rowIDs.count <= policy.maximumRows,max(state.q.count,state.v.count) <= policy.maximumCoordinates else { throw .invalidShape }
        try validatePrescribed(state,work:&work)
        guard state.time >= minimumTime,state.time <= maximumTime else { throw .outsideDomain }
        for i in state.q.indices { guard state.q[i] >= minimumPosition[i],state.q[i] <= maximumPosition[i] else { throw .outsideDomain } }
        try GeometricArithmetic.numeric { () throws(NumericalError) -> Void in try work.requireStorage(scalarStorage) }
        try GeometricArithmetic.charge(try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.product(512,try NumericalWork.product(model.tree.bodies.count,state.v.count+1)) },&work)
        let snapshot:KinematicSnapshot
        do { snapshot=try model.evaluate(model.makeState(state)) } catch { throw .invalidChart }
        try GeometricArithmetic.check(policy);return snapshot
    }
    public func validatePrescribed(_ state:KinematicState,work:inout NumericalWork) throws(GeometricConstraintError) {
        if let program=prescribedMotion {
            do throws(PrescribedMotionError) {
                let supplied=try PrescribedMotionSample(metadata:program.metadata,time:state.time,anchors:state.prescribedAnchors,policy:program.policy)
                _=try OriginalPrescribedMotionAcceptance.validated(supplied,program:program,time:state.time,policy:program.policy,work:&work)
            } catch { throw .motion(error) }
        } else if !state.prescribedAnchors.isEmpty { throw .staleSource }
    }
    internal static func isPrescribed(_ endpoint:GeometricFrameEndpoint,tree:KinematicTree) -> Bool {
        tree.joints.contains { joint in
            guard joint.parentBody == endpoint.body,joint.parentAnchor.frame == endpoint.frame else { return false }
            if case .prescribed=joint.parentAnchor.placement { return true };return false
        }
    }

}

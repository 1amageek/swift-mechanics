internal enum GeometryParameterAdmission {
    // FIXME(INCOMPLETE_IMPLEMENTATION): Topology, moving-anchor, floating-root and derived multi-axis chart products are unavailable. ExactGeometryParameterDifferentiator calls this admission before any publication; support needs original chart/source and directional behavioral evidence.
    static func validate(_ source: GeometryParameterSource, direction: [Double], policy: GeometryParameterPolicy,
                         work: inout NumericalWork) throws(GeometryParameterError) {
        try GeometryParameterArithmetic.checkpoint(policy)
        let tree = source.tree, state = source.state, n = tree.layout.velocityCount
        guard tree.bodies.count <= policy.maximumBodies, n <= policy.maximumVelocities,
              source.bindings.count <= policy.maximumParameters else { throw .capacityExceeded }
        guard state.revision == tree.revision else { throw .derivativeUnavailable(.sourceMapping) }
        guard direction.count == source.bindings.count, state.q.count == tree.layout.positionCount,
              state.v.count == n, state.acceleration.count == n else { throw .invalidShape }
        try GeometryParameterArithmetic.charge(direction.count, &work)
        guard direction.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        guard tree.rootBase == .fixed else { throw .derivativeUnavailable(.floatingRoot) }
        guard state.prescribedAnchors.isEmpty else { throw .derivativeUnavailable(.movingAnchor) }
        guard tree.layout.positionCount == n, tree.joints.count == tree.layout.joints.count else { throw .derivativeUnavailable(.unsupportedJointChart) }
        try GeometryParameterArithmetic.bytes(source.modelSource.source, policy: policy, work: &work)
        try GeometryParameterArithmetic.bytes(tree.worldFrame.key, policy: policy, work: &work)
        for body in tree.bodies {
            try GeometryParameterArithmetic.checkpoint(policy); try GeometryParameterArithmetic.charge(1, &work)
            guard body.dimension == .spatial else { throw .derivativeUnavailable(.nonSpatialTree) }
            try GeometryParameterArithmetic.bytes(body.id.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(body.frame.key, policy: policy, work: &work)
        }
        for i in tree.joints.indices {
            try GeometryParameterArithmetic.checkpoint(policy); try GeometryParameterArithmetic.charge(16, &work)
            let joint = tree.joints[i], chart = joint.manifold, layout = tree.layout.joints[i]
            try GeometryParameterArithmetic.bytes(joint.id.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(joint.parentBody.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(joint.childBody.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(joint.parentAnchor.frame.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(joint.childAnchor.frame.key, policy: policy, work: &work)
            guard case .fixed = joint.parentAnchor.placement, case .fixed = joint.childAnchor.placement else { throw .derivativeUnavailable(.movingAnchor) }
            guard layout.joint == joint.id, layout.positions == layout.velocities else { throw .derivativeUnavailable(.unsupportedJointChart) }
            switch chart.kind {
            case .fixed:
                guard chart.orderedAxes.isEmpty, chart.positionCount == 0, chart.velocityCount == 0, layout.positions.count == 0 else { throw .derivativeUnavailable(.unsupportedJointChart) }
            case .revolute, .prismatic, .screw:
                guard chart.positionCount == 1, chart.velocityCount == 1, chart.orderedAxes.count == 1, layout.positions.count == 1 else { throw .derivativeUnavailable(.unsupportedJointChart) }
                let axis = chart.orderedAxes[0]
                guard (chart.kind == .revolute && axis.kind == .revolute) || (chart.kind == .prismatic && axis.kind == .prismatic) ||
                      (chart.kind == .screw && axis.kind == .screw) else { throw .derivativeUnavailable(.unsupportedJointChart) }
            default: throw .derivativeUnavailable(.unsupportedJointChart)
            }
        }
        for i in source.bindings.indices {
            try GeometryParameterArithmetic.checkpoint(policy)
            let binding = source.bindings[i]
            try GeometryParameterArithmetic.bytes(binding.modelSource.source, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(binding.parameterSource.source, policy: policy, work: &work)
            guard binding.modelSource == source.modelSource, binding.treeRevision == tree.revision else { throw .derivativeUnavailable(.sourceMapping) }
            for j in 0..<i {
                try GeometryParameterArithmetic.checkpoint(policy); try GeometryParameterArithmetic.charge(1, &work)
                guard source.bindings[j].parameterID != binding.parameterID else { throw .invalidInput }
            }
            switch binding.target {
            case .fixedRoot(let body, let frame):
                try GeometryParameterArithmetic.bytes(body.key, policy: policy, work: &work); try GeometryParameterArithmetic.bytes(frame.key, policy: policy, work: &work)
            case .fixedAnchor(let joint, let frame):
                try GeometryParameterArithmetic.bytes(joint.key, policy: policy, work: &work); try GeometryParameterArithmetic.bytes(frame.key, policy: policy, work: &work)
            case .jointAxis(let joint, _): try GeometryParameterArithmetic.bytes(joint.key, policy: policy, work: &work)
            case .topology: throw .derivativeUnavailable(.topologyChange)
            }
        }
    }

    static func resolve(_ source: GeometryParameterSource, direction: [Double], policy: GeometryParameterPolicy,
                        work: inout NumericalWork) throws(GeometryParameterError) -> GeometryResolvedDirections {
        let count = try GeometryParameterArithmetic.sum(GeometryParameterArithmetic.product(source.tree.joints.count, 2), 1)
        var translations = [Vector3](repeating: .zero, count: count), rotations = translations
        var axes = [Vector3](repeating: .zero, count: source.tree.layout.velocityCount)
        var witnesses: [GeometryAxisWitness] = []; witnesses.reserveCapacity(source.bindings.count)
        for (i, binding) in source.bindings.enumerated() {
            try GeometryParameterArithmetic.checkpoint(policy)
            switch binding.target {
            case .fixedRoot(let body, let frame):
                guard source.tree.bodies[0].id == body, source.tree.bodies[0].frame == frame else { throw .derivativeUnavailable(.sourceMapping) }
                try placement(binding.chart, actual: source.tree.bodies[0].referencePose, direction: direction[i], index: 0,
                              translations: &translations, rotations: &rotations, work: &work)
            case .fixedAnchor(let joint, let frame):
                let index = try jointIndex(joint, source: source, policy: policy, work: &work)
                let actual = source.tree.joints[index]
                let anchor: JointAnchor, slot: Int
                if frame == actual.parentAnchor.frame { anchor = actual.parentAnchor; slot = 1 + 2*index }
                else if frame == actual.childAnchor.frame { anchor = actual.childAnchor; slot = 2 + 2*index }
                else { throw .derivativeUnavailable(.sourceMapping) }
                guard case .fixed(let pose) = anchor.placement else { throw .derivativeUnavailable(.movingAnchor) }
                try placement(binding.chart, actual: pose, direction: direction[i], index: slot,
                              translations: &translations, rotations: &rotations, work: &work)
            case .jointAxis(let joint, let axisIndex):
                let index = try jointIndex(joint, source: source, policy: policy, work: &work)
                guard axisIndex == 0, source.tree.joints[index].manifold.orderedAxes.count == 1,
                      case .normalizedAxis(let raw, let perUnit) = binding.chart else { throw .derivativeUnavailable(.referenceChartMismatch) }
                let d = try GeometryParameterArithmetic.core { () throws(CoreError) in try perUnit.scaled(by: direction[i]) }
                let jet = try GeometryParameterArithmetic.normalize(GeometryVectorJet(raw, d), minimum: policy.minimumRawAxisMagnitude, work: &work)
                var agreement = GeometryOriginalAcceptance()
                do throws(GeometryParameterError) {
                    try agreement.vector(jet.value, source.tree.joints[index].manifold.orderedAxes[0].direction, tolerance: policy.primalTolerance, primal: true, work: &work)
                } catch {
                    switch error {
                    case .originalPrimalMismatch: throw .derivativeUnavailable(.referenceChartMismatch)
                    default: throw error
                    }
                }
                let coordinate = source.tree.layout.joints[index].velocities.start
                try GeometryParameterArithmetic.charge(3, &work)
                axes[coordinate] = try GeometryParameterArithmetic.core { () throws(CoreError) in try axes[coordinate].adding(jet.direction) }
                witnesses.append(GeometryAxisWitness(parameterID: binding.parameterID, rawReference: raw, normalizedAxis: jet.value, normalizedDirection: jet.direction))
            // FIXME(INCOMPLETE_IMPLEMENTATION): Topology directions have no smooth fixed-tree operator. Public direction admission and this resolution refuse them until an explicit topology derivative contract exists.
            case .topology: throw .derivativeUnavailable(.topologyChange)
            }
        }
        return GeometryResolvedDirections(translations: translations, bodyRotations: rotations, axes: axes, witnesses: witnesses)
    }
    private static func placement(_ chart: GeometryParameterChart, actual: RigidTransform, direction: Double, index: Int,
                                  translations: inout [Vector3], rotations: inout [Vector3], work: inout NumericalWork) throws(GeometryParameterError) {
        try GeometryParameterArithmetic.charge(20, &work)
        switch chart {
        case .translation(let reference, let perMeter):
            guard reference == actual else { throw .derivativeUnavailable(.referenceChartMismatch) }
            translations[index] = try GeometryParameterArithmetic.core { () throws(CoreError) in try translations[index].adding(perMeter.scaled(by: direction)) }
        case .rotation(let reference, let tangent):
            guard reference == actual else { throw .derivativeUnavailable(.referenceChartMismatch) }
            rotations[index] = try GeometryParameterArithmetic.core { () throws(CoreError) in try rotations[index].adding(tangent.scaled(by: direction)) }
        case .normalizedAxis: throw .derivativeUnavailable(.referenceChartMismatch)
        }
    }
    private static func jointIndex(_ id: EntityID, source: GeometryParameterSource, policy: GeometryParameterPolicy,
                                   work: inout NumericalWork) throws(GeometryParameterError) -> Int {
        for i in source.tree.joints.indices {
            try GeometryParameterArithmetic.checkpoint(policy); try GeometryParameterArithmetic.charge(1, &work)
            try GeometryParameterArithmetic.bytes(id.key, policy: policy, work: &work)
            try GeometryParameterArithmetic.bytes(source.tree.joints[i].id.key, policy: policy, work: &work)
            if source.tree.joints[i].id == id { return i }
        }
        throw .derivativeUnavailable(.sourceMapping)
    }
}

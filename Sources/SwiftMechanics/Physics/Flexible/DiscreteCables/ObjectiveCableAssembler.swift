public struct ObjectiveCableAssembler: CableAssembling, Sendable {
    public init() {}

    public func assemble(_ cable: DiscreteCable, state: NodalState, derivativeOrder: CableDerivativeOrder,
                         policy: CablePolicy, work: inout NumericalWork) throws(CableError) -> CableAssembly {
        try CableArithmetic.check(policy)
        let n = cable.nodes.count
        guard n <= policy.maximumNodes else { throw .capacityExceeded }
        guard state.positions.count == n, state.velocities.count == n, state.nodeIdentifiers.count == n else { throw .layoutMismatch }
        try CableArithmetic.metadata(cable, state: state, policy: policy, work: &work)
        guard state.frame == cable.frame, state.meshRevision == cable.revision else { throw .layoutMismatch }
        try CableArithmetic.reserve(n, &work)
        for i in 0..<n {
            try CableArithmetic.check(policy)
            try CableArithmetic.charge(try CableArithmetic.sum(i,1), &work)
            guard state.nodeIdentifiers[i] == cable.nodes[i].identifier else { throw .layoutMismatch }
            for j in 0..<i { guard cable.nodes[j].identifier != cable.nodes[i].identifier else { throw .duplicateNode } }
        }
        let m = cable.material
        let young = try CableArithmetic.finite(9 / (3 / m.elasticity.shearModulus + 1 / m.elasticity.bulkModulus))
        let axial = try CableArithmetic.finite(young * m.area), bend = try CableArithmetic.finite(young * m.secondMoment)
        guard young > 0, axial > 0, m.secondMoment == 0 || bend > 0 else { throw .nonFiniteResult }
        var restLengths = [Double](repeating: 0, count: n-1)
        var masses = [Double](repeating: 0, count: n)
        var force = [Vector3](repeating: .zero, count: n)
        var blocks: [CableStiffnessBlock] = []
        if derivativeOrder == .forceAndTangent {
            blocks.reserveCapacity(try CableArithmetic.sum(CableArithmetic.product(4,n-1), CableArithmetic.product(9,n-2)))
        }
        var energy = 0.0, totalMass = 0.0
        for i in 0..<n-1 {
            try CableArithmetic.check(policy)
            try CableArithmetic.charge(40, &work)
            let restEdge = try CableArithmetic.subtract(cable.nodes[i+1].referencePosition,cable.nodes[i].referencePosition)
            let l0 = try CableArithmetic.segmentLength(restEdge,minimum: policy.minimumSegmentLength,segment: i)
            restLengths[i] = l0
            let mass = try CableArithmetic.finite(m.referenceDensity * m.area * l0)
            guard mass > 0, mass * 0.5 > 0 else { throw .nonFiniteResult }
            masses[i] = try CableArithmetic.finite(masses[i]+mass*0.5)
            masses[i+1] = try CableArithmetic.finite(masses[i+1]+mass*0.5)
            totalMass = try CableArithmetic.finite(totalMass+mass)
            // Conservatively bounds the fixed six-coordinate analytic expression and assembly.
            try CableArithmetic.charge(20000, &work)
            let a = edge(state.positions[i],state.positions[i+1], count: 6, first: 0, second: 3)
            let length = try norm(a, minimum: policy.minimumSegmentLength, segment: i)
            let strain = try CableArithmetic.finite((length.value-l0)/l0)
            guard abs(strain) <= m.maximumAbsoluteAxialStrain else { throw .outsideAxialDomain(index: i) }
            if cable.formulation == .tensionOnlyCable {
                if length.value == l0, derivativeOrder == .forceAndTangent { throw .nonsmoothStretch(index: i) }
                if length.value <= l0 { continue }
            }
            let extensionJet = length.adding(CableJet(-l0,count: 6))
            let coefficient = try CableArithmetic.finite(0.5*axial/l0)
            guard coefficient > 0 else { throw .nonFiniteResult }
            let e = extensionJet.multiplied(extensionJet).scaled(coefficient)
            try accumulate(e, nodes: [i,i+1], force: &force, blocks: &blocks, energy: &energy, order: derivativeOrder)
        }
        if bend > 0, n > 2 {
            for i in 1..<n-1 {
                try CableArithmetic.check(policy)
                // Includes all temporaries of two normalized vectors and their squared difference.
                try CableArithmetic.charge(100000, &work)
                let a = edge(state.positions[i-1],state.positions[i], count: 9, first: 0, second: 3)
                let b = edge(state.positions[i],state.positions[i+1], count: 9, first: 3, second: 6)
                let la = try norm(a, minimum: policy.minimumSegmentLength, segment: i-1)
                let lb = try norm(b, minimum: policy.minimumSegmentLength, segment: i)
                let ia = try la.reciprocal(), ib = try lb.reciprocal()
                var squared = CableJet(0,count: 9)
                for axis in 0..<3 {
                    let difference = a[axis].multiplied(ia).subtracting(b[axis].multiplied(ib))
                    squared = squared.adding(difference.multiplied(difference))
                }
                let dual = try CableArithmetic.finite(restLengths[i-1]*0.5+restLengths[i]*0.5)
                let coefficient = try CableArithmetic.finite(0.5*bend/dual)
                guard coefficient > 0 else { throw .nonFiniteResult }
                let e = squared.scaled(coefficient)
                try accumulate(e, nodes: [i-1,i,i+1], force: &force, blocks: &blocks, energy: &energy, order: derivativeOrder)
            }
        }
        var damping = [Double](repeating: 0,count: n)
        var dampingForce = [Vector3](repeating: .zero,count: n)
        var power = 0.0
        for i in 0..<n {
            try CableArithmetic.check(policy); try CableArithmetic.charge(30,&work)
            guard masses[i] > 0 else { throw .nonFiniteResult }
            damping[i] = try CableArithmetic.finite(m.massDampingRate*masses[i])
            guard m.massDampingRate == 0 || damping[i] > 0 else { throw .nonFiniteResult }
            dampingForce[i] = try CableArithmetic.scale(state.velocities[i],-damping[i])
            power = try CableArithmetic.finite(power + damping[i]*CableArithmetic.dot(state.velocities[i],state.velocities[i]))
        }
        try CableArithmetic.check(policy)
        return CableAssembly(cable: cable, derivativeOrder: derivativeOrder, physicalInternalForce: force,
                             stiffnessBlocks: derivativeOrder == .forceAndTangent ? blocks : nil,
                             lumpedNodeMass: masses, dampingDiagonal: damping, physicalDampingForce: dampingForce,
                             storedEnergy: energy, dissipatedPower: power, totalReferenceMass: totalMass, numericalWork: work)
    }

    private func edge(_ a: Vector3, _ b: Vector3, count: Int, first: Int, second: Int) -> [CableJet] {
        var result: [CableJet] = []; result.reserveCapacity(3)
        for axis in 0..<3 {
            result.append(CableJet(CableArithmetic.component(b,axis),count: count,coordinate: second+axis)
                .subtracting(CableJet(CableArithmetic.component(a,axis),count: count,coordinate: first+axis)))
        }
        return result
    }
    private func norm(_ vector: [CableJet], minimum: Double, segment: Int) throws(CableError) -> CableJet {
        let scale = max(abs(vector[0].value),max(abs(vector[1].value),abs(vector[2].value)))
        guard scale.isFinite else { throw .nonFiniteResult }
        guard scale > 0 else { throw .degenerateSegment(index: segment) }
        var squared = CableJet(0,count: vector[0].gradient.count)
        for component in vector {
            let normalized = component.divided(by: scale)
            squared = squared.adding(normalized.multiplied(normalized))
        }
        let length = try squared.squareRoot().scaled(scale)
        guard length.value.isFinite else { throw .nonFiniteResult }
        guard length.value >= minimum else { throw .degenerateSegment(index: segment) }
        return length
    }
    private func accumulate(_ e: CableJet, nodes: [Int], force: inout [Vector3], blocks: inout [CableStiffnessBlock],
                            energy: inout Double, order: CableDerivativeOrder) throws(CableError) {
        try e.validate(includeHessian: order == .forceAndTangent)
        energy = try CableArithmetic.finite(energy+e.value)
        let dof = 3*nodes.count
        for i in nodes.indices {
            let physical = try CableArithmetic.vector(-e.gradient[3*i],-e.gradient[3*i+1],-e.gradient[3*i+2])
            force[nodes[i]] = try CableArithmetic.add(force[nodes[i]],physical)
            if order == .forceAndTangent {
                for j in nodes.indices {
                    let offset = 3*i*dof+3*j
                    let block = try CableArithmetic.core { () throws(CoreError) in
                        try Matrix3(e.hessian[offset],e.hessian[offset+1],e.hessian[offset+2],
                                    e.hessian[offset+dof],e.hessian[offset+dof+1],e.hessian[offset+dof+2],
                                    e.hessian[offset+2*dof],e.hessian[offset+2*dof+1],e.hessian[offset+2*dof+2])
                    }
                    blocks.append(CableStiffnessBlock(rowNode: nodes[i],columnNode: nodes[j],value: block))
                }
            }
        }
    }
}

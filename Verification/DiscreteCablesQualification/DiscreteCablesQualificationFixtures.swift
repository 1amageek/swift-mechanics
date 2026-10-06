import SwiftMechanics

internal enum DiscreteCablesQualificationFixtures {
    typealias E = DiscreteCablesQualificationError
    static func require(_ condition: Bool, _ label: String) throws(E) {
        guard condition else { throw .assertion(label) }
    }
    static func near(_ actual: Double, _ expected: Double, _ label: String,
                     absolute: Double = 1e-11, relative: Double = 1e-9) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= absolute+relative*max(abs(actual),abs(expected)), label)
    }
    static func near(_ actual: [Double], _ expected: [Double], _ label: String,
                     absolute: Double = 1e-11, relative: Double = 1e-9) throws(E) {
        try require(actual.count == expected.count, label+" count")
        for i in expected.indices { try near(actual[i],expected[i],label+" "+String(i),absolute: absolute,relative: relative) }
    }
    static func cable<T>(_ body: () throws(CableError) -> T) throws(E) -> T {
        do throws(CableError) { return try body() } catch { throw .producer(error) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T {
        do throws(ModelError) { return try body() } catch { throw .model(error) }
    }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T {
        do throws(MaterialError) { return try body() } catch { throw .material(error) }
    }
    static func work(storage: Int = 20_000, operations: Int = 10_000_000,
                     iterations: Int = 64) throws(E) -> NumericalWork {
        do throws(NumericalError) {
            return NumericalWork(budget: try NumericalBudget(scalarStorage: storage,arithmeticOperations: operations,iterations: iterations))
        } catch { throw .numerical(error) }
    }
    static func vectors(_ flat: [Double]) throws(E) -> [Vector3] {
        try require(flat.count % 3 == 0,"fixture vector layout")
        var result: [Vector3] = []
        for i in stride(from: 0,to: flat.count,by: 3) {
            result.append(try core { () throws(CoreError) in try Vector3(flat[i],flat[i+1],flat[i+2]) })
        }
        return result
    }
    static func flat(_ values: [Vector3]) -> [Double] {
        var result: [Double] = []
        for value in values { result += [value.x,value.y,value.z] }
        return result
    }
    static func policy(nodes: Int = 8, metadata: Int = 512, attempts: Int = 64,
                       minimumStep: Double = 1e-8, energy: Double = 0.001,
                       cancelled: @escaping @Sendable () -> Bool = { false }) throws(E) -> CablePolicy {
        try cable { () throws(CableError) in
            try CablePolicy(maximumNodes: nodes,maximumMetadataBytes: metadata,minimumSegmentLength: 1e-9,
                maximumAttempts: attempts,minimumSubstep: minimumStep,absoluteEnergyTolerance: energy,
                absoluteMomentumTolerance: 1e-11,absoluteAngularMomentumTolerance: 1e-11,
                relativeTolerance: 0,isCancelled: cancelled)
        }
    }
    static func chain(_ rest: [Double] = [0,0,0,1,0,0,2,0,0], secondMoment: Double = 0.025,
                      damping: Double = 0, strain: Double = 2,
                      formulation: CableFormulation = .bilateralSpringChain,
                      identifiers: [UInt64]? = nil) throws(E) -> DiscreteCable {
        let frame = try model { () throws(ModelError) in try EntityID(kind: .frame,key: "cable-frame") }
        let source = try model { () throws(ModelError) in try SourceProvenance(source: "cable-source",revision: 7) }
        let materialID = try model { () throws(ModelError) in try EntityID(kind: .material,key: "cable-material") }
        let elasticity = try Self.material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus: 200/3.0,shearModulus: 50) }
        let material = try cable { () throws(CableError) in
            try CableMaterial(identifier: materialID,source: source,elasticity: elasticity,referenceDensity: 4,
                area: 0.5,secondMoment: secondMoment,massDampingRate: damping,maximumAbsoluteAxialStrain: strain)
        }
        let positions = try vectors(rest)
        if let identifiers { try require(identifiers.count == positions.count,"fixture node IDs") }
        var nodes: [FlexibleNode] = []
        for i in positions.indices { nodes.append(FlexibleNode(identifier: identifiers?[i] ?? UInt64(i+1),referencePosition: positions[i])) }
        return try cable { () throws(CableError) in try DiscreteCable(frame: frame,revision: 11,source: source,nodes: nodes,material: material,formulation: formulation) }
    }
    static func state(_ chain: DiscreteCable, _ positions: [Double]? = nil,
                      velocity: [Double]? = nil, frame: EntityID? = nil, revision: UInt64? = nil,
                      identifiers: [UInt64]? = nil) throws(E) -> NodalState {
        let x: [Vector3]
        if let positions { x = try vectors(positions) } else { x = chain.nodes.map(\.referencePosition) }
        let v: [Vector3]
        if let velocity { v = try vectors(velocity) } else { v = [Vector3](repeating: .zero,count: x.count) }
        return NodalState(frame: frame ?? chain.frame,meshRevision: revision ?? chain.revision,
            nodeIdentifiers: identifiers ?? chain.nodes.map(\.identifier),positions: x,velocities: v)
    }
    static func assemble(_ chain: DiscreteCable, _ state: NodalState, order: CableDerivativeOrder = .forceAndTangent,
                         policy: CablePolicy? = nil) throws(E) -> CableAssembly {
        var work = try Self.work()
        let admission: CablePolicy
        if let policy { admission = policy } else { admission = try Self.policy() }
        let service: any CableAssembling = ObjectiveCableAssembler()
        return try cable { () throws(CableError) in try service.assemble(chain,state: state,derivativeOrder: order,policy: admission,work: &work) }
    }
    static func matrix(_ assembly: CableAssembly) throws(E) -> [Double] {
        guard let blocks = assembly.stiffnessBlocks else { throw .assertion("original tangent omitted") }
        let n = assembly.cable.nodes.count*3
        var result = [Double](repeating: 0,count: n*n)
        for block in blocks {
            try require(block.rowNode >= 0 && block.rowNode*3 < n && block.columnNode >= 0 && block.columnNode*3 < n,"original block node bounds")
            for i in 0..<3 { for j in 0..<3 {
                result[(block.rowNode*3+i)*n+block.columnNode*3+j] += try core { () throws(CoreError) in try block.value.element(row: i,column: j) }
            } }
        }
        return result
    }
    static func loads(_ chain: DiscreteCable, forces: [Double]? = nil,
                      gravity: [Double] = [0,0,0], fixed: [Bool]? = nil) throws(E) -> CableLoads {
        let values = try vectors(forces ?? [Double](repeating: 0,count: 3*chain.nodes.count))
        let g = try vectors(gravity); try require(g.count == 1,"fixture gravity layout")
        return CableLoads(frame: chain.frame,revision: chain.revision,nodeIdentifiers: chain.nodes.map(\.identifier),
                          heldNodalForces: values,heldGravity: g[0],fixedNodes: fixed ?? [Bool](repeating: false,count: chain.nodes.count))
    }
    static func accepted(_ result: CableEvolutionResult, _ label: String) throws(E) -> (NodalState,CableEvolutionEvidence) {
        switch result {
        case let .accepted(state,evidence): return (state,evidence)
        case let .rejected(_,reason,_): throw .producer(reason)
        }
    }
    static func sameState(_ actual: NodalState, _ original: NodalState, _ label: String) throws(E) {
        try require(actual.frame == original.frame && actual.meshRevision == original.meshRevision &&
            actual.nodeIdentifiers == original.nodeIdentifiers && actual.positions == original.positions &&
            actual.velocities == original.velocities,label+" full original state")
    }
    static func rejected(_ result: CableEvolutionResult, original: NodalState, cause: CableError,
                         _ label: String) throws(E) -> NumericalWork {
        switch result {
        case .accepted: throw .assertion(label+" unexpectedly accepted")
        case let .rejected(state,reason,work):
            try require(reason == cause,label+" original typed cause")
            try sameState(state,original,label)
            return work
        }
    }
    static func expect(_ expected: CableError, _ label: String, _ body: () throws(CableError) -> Void) throws(E) {
        do throws(CableError) { try body() } catch { try require(error == expected,label+" original typed cause"); return }
        throw .assertion(label+" unexpectedly succeeded")
    }
}

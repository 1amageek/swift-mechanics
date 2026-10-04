import SwiftMechanics

private struct DeclarativeHingeProbe: Machine {
    let input: MechanicalDescriptor
    let branch: Int

    var body: some Machine {
        MachineBody(input.bodies[0])
        if branch >= 0 {
            MachineBody(input.bodies[1])
        }
        switch branch {
        case 0:
            MachineJoint(input.joints[0])
        case 1:
            AnyMachine(MachineJoint(input.joints[0]))
        default:
            MachineGroup { MachineJoint(input.joints[0]) }
        }
        if let empty = Optional(EmptyMachine()) { empty }
        for _ in 0..<2 { EmptyMachine() }
        AnyMachine(AnyMachine(EmptyMachine()))
    }
}

extension FoundationVerification {
    static func verifyMachines() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let input = try compilerDescriptor(inertiaPolicy: inertia, displacedChild: false)
        let policy = try MachineDefinitionPolicy(maximumNodes: 100, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumDepth: 32, maximumIterations: 8)
        let compilation = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2,
            maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9,
                characteristicLengthMeters: 1), inertiaPolicy: inertia,
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 20,
            maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 1, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: compilerVerificationTarget)
        for branch in 0...2 {
            let definition = MachineDefinition(identity: "declarative-hinge", revision: input.revision,
                root: input.root, rootBase: input.rootBase, rootAuthority: input.rootAuthority,
                worldFrame: input.worldFrame, initialState: input.initialState) {
                DeclarativeHingeProbe(input: input, branch: branch)
            }
            let descriptor = try definition.makeDescriptor(policy: policy)
            try require(descriptor.bodies == input.bodies && descriptor.joints == input.joints)
            let model = try definition.compile(definitionPolicy: policy, compilationPolicy: compilation)
            let motion = try model.evaluate(model.makeState(input.initialState))
            try require(try motion.body(input.bodies[0].id).motion.velocity.angular == Vector3(0, 0, 2))
        }
        let scoped = MachineDefinition(identity: "scoped-hinge", revision: input.revision,
            root: input.root, rootBase: input.rootBase, rootAuthority: input.rootAuthority,
            worldFrame: input.worldFrame, initialState: input.initialState) {
            MachineBody(input.bodies[1])
            MachineInstance(id: "assembly") {
                MachineBody(input.bodies[0])
                MachineJoint(input.joints[0], parent: .absolute(input.root))
            }
        }
        let scopedModel = try scoped.compile(definitionPolicy: policy, compilationPolicy: compilation)
        let child = try MachineDefinitionContext.scopedIdentity(input.bodies[0].id, namespace: ["assembly"])
        try require(try scopedModel.evaluate(scopedModel.makeState(input.initialState)).body(child).motion.velocity.angular == Vector3(0, 0, 2))
        let duplicate = MachineDefinition(identity: "duplicate", revision: input.revision,
            root: input.root, rootBase: input.rootBase, rootAuthority: input.rootAuthority,
            worldFrame: input.worldFrame, initialState: input.initialState) {
            MachineBody(input.bodies[0]); MachineBody(input.bodies[0])
        }
        var rejected = false
        do throws(MachineDefinitionFailure) { _ = try duplicate.makeDescriptor(policy: policy) }
        catch {
            guard case .duplicateIdentity = error else { throw FoundationVerificationError.analyticCheckFailed }
            rejected = true
        }
        try require(rejected)
        let bounded = MachineDefinition(identity: "bounded", revision: input.revision,
            root: input.root, rootBase: input.rootBase, rootAuthority: input.rootAuthority,
            worldFrame: input.worldFrame, initialState: input.initialState) {
            ForEachMachine(0..<3, id: { String($0) }) { _ in EmptyMachine() }
        }
        let limit = try MachineDefinitionPolicy(maximumNodes: 100, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumDepth: 32, maximumIterations: 2)
        rejected = false
        do throws(MachineDefinitionFailure) { _ = try bounded.makeDescriptor(policy: limit) }
        catch {
            guard error == .capacityExceeded else { throw FoundationVerificationError.analyticCheckFailed }
            rejected = true
        }
        try require(rejected)
        print("Machine runtime verification passed: selected branches, erased composition, scoped hinge motion and typed duplicate/iteration failure.")
    }
}

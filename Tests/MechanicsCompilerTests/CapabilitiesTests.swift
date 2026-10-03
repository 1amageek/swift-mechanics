import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCompiler

@Suite struct CapabilitiesTests {
    private func spring(stiffness: Double = 10, dimension: PhysicalDimension = PhysicalDimension(mass: 1, time: -2)) throws -> MechanicalExtensionRecord {
        try MechanicalExtensionRecord(id: CompilerFixtures.id(.load, "spring"), schema: "spring", references: [CompilerFixtures.id(.body, "root"), CompilerFixtures.id(.body, "child")],
            parameters: [ExtensionParameter(name: "stiffness", value: stiffness, dimension: dimension), ExtensionParameter(name: "restLength", value: 1, dimension: .length)])
    }
    @Test func actualSchemaDomainProofAndQualifiedMeaning() throws {
        let record = try spring(), policy = try CompilerFixtures.policy()
        let descriptor = try CompilerFixtures.descriptor(extensions: [record])
        let model = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator()).compile(descriptor, policy: policy)
        #expect(model.report.extensionCount == 1)
        #expect(model.extensionEvidence.first?.work.operations == 12)
        #expect(model.manifest.entries.contains { $0.requirement.feature == "spring.descriptor" && $0.qualification == .descriptorValidated(modelRevision: 1) })
        #expect(model.manifest.entries.contains { entry in
            if entry.requirement.operation == .treeKinematics, case .executionUnqualified = entry.qualification { return true }
            return false
        })
        let bad = try CompilerFixtures.descriptor(extensions: [spring(stiffness: -1)])
        let compiler = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator())
        CompilerFixtures.failure(.invalidLawDomain, record: record.id) { () throws(CompilationFailure) in _ = try compiler.compile(bad, policy: policy) }
        let wrongDimension = try CompilerFixtures.descriptor(extensions: [spring(dimension: .force)])
        CompilerFixtures.failure(.invalidLawDomain) { () throws(CompilationFailure) in _ = try compiler.compile(wrongDimension, policy: policy) }
        CompilerFixtures.failure(.unknownSchema) { () throws(CompilationFailure) in _ = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy) }
    }
    @Test func registrationsEvidenceAndCumulativeWorkAreBounded() throws {
        let descriptor = try CompilerFixtures.descriptor(extensions: [spring()]), policy = try CompilerFixtures.policy()
        let duplicate = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator(registrationCount: 2))
        CompilerFixtures.failure(.duplicateRegistration) { () throws(CompilationFailure) in _ = try duplicate.compile(descriptor, policy: policy) }
        let overCapacity = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator(registrationCount: 1001))
        CompilerFixtures.failure(.capacityExceeded) { () throws(CompilationFailure) in _ = try overCapacity.compile(descriptor, policy: policy) }
        let forged = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator(forgedFeature: true))
        CompilerFixtures.failure(.invalidValidatorEvidence) { () throws(CompilationFailure) in _ = try forged.compile(descriptor, policy: policy) }
        let limited = try CompilerFixtures.policy(operations: 11), compiler = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator())
        CompilerFixtures.failure(.validatorBudgetExceeded) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: limited) }
        let first = try spring()
        let second = try MechanicalExtensionRecord(id: CompilerFixtures.id(.load, "second"), schema: first.schema, references: first.references, parameters: first.parameters)
        let two = try CompilerFixtures.descriptor(extensions: [first,second]), combined = try CompilerFixtures.policy(operations: 23)
        CompilerFixtures.failure(.validatorBudgetExceeded) { () throws(CompilationFailure) in _ = try compiler.compile(two, policy: combined) }
    }
    @Test func declarationsCannotGrantExecutionBackendOrLoopSupport() throws {
        let policy = try CompilerFixtures.policy(), compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        for operation in [FeatureOperation.forwardDynamics, .contactResponse, .loopAssembly, .forceEvaluation, .timeIntegration, .treeKinematics] {
            let request = try FeatureRequirement(feature: "mechanics.compiler.tree", operation: operation, domain: .spatialTree, precision: .float64, backend: .referenceCPU, target: .nativeCPU)
            let descriptor = try CompilerFixtures.descriptor(features: [request])
            CompilerFixtures.failure(.unsupportedCapability) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: policy) }
        }
        let wrongPrecision = try FeatureRequirement(feature: "mechanics.compiler.tree", operation: .descriptorValidation, domain: .spatialTree, precision: .float32, backend: .referenceCPU, target: .nativeCPU)
        let descriptor = try CompilerFixtures.descriptor(features: [wrongPrecision])
        CompilerFixtures.failure(.unsupportedCapability) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: policy) }
        let fakeOwner = try ReferenceMechanicalCompiler(extensions: SpringDescriptorValidator(operation: .forwardDynamics))
        CompilerFixtures.failure(.unsupportedCapability) { () throws(CompilationFailure) in _ = try fakeOwner.compile(descriptor, policy: policy) }
    }
}

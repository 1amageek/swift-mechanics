/// Real producer-to-consumer composition; Runtime/session/lease ownership stays with the caller.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceStructuralMechanismFactory: StructuralMechanismCreating {
    public init() {}

    public func equation(_ system: StructuralMechanicalSystem, identity: String,
        policy: MechanismSolvePolicy, admission: DynamicsAdmission, maximumIdentityBytes: Int
    ) throws(StructuralSystemFailure) -> AffineMechanismEquation {
        // FIXME(INCOMPLETE_IMPLEMENTATION): A system with no ideal relation reaches here.
        // The existing affine consumer requires original constraint rows; unconstrained
        // composition must use its actual dynamics consumer, never a fabricated zero row.
        guard let network = system.transmission else { throw .missingTransmission }
        // The base equation cannot consume a passive catalog. Use loadedEquation instead
        // of dropping declared physical laws while reporting an executable mechanism.
        guard system.passiveCatalog == nil else { throw .requiresLoadedEquation }
        return try base(system, network: network, identity: identity, policy: policy,
            admission: admission, maximumIdentityBytes: maximumIdentityBytes)
    }

    public func loadedEquation(_ system: StructuralMechanicalSystem, identity: String,
        policy: MechanismSolvePolicy, admission: DynamicsAdmission, execution: any StationaryLoadExecuting,
        maximumIdentityBytes: Int
    ) throws(StructuralSystemFailure) -> StationaryAffineMechanismEquation {
        // FIXME(INCOMPLETE_IMPLEMENTATION): A loaded system with no ideal relation reaches here.
        // The original affine consumer requires nonempty physical rows; actual unconstrained
        // loaded dynamics must be implemented and qualified before this domain can succeed.
        guard let network = system.transmission else { throw .missingTransmission }
        guard let catalog = system.passiveCatalog, let selection = system.passiveSelection else { throw .missingPassiveCatalog }
        let equation = try base(system, network: network, identity: identity, policy: policy,
            admission: admission, maximumIdentityBytes: maximumIdentityBytes)
        do {
            return try StationaryAffineMechanismEquation(base: equation, catalog: catalog, selection: selection,
                execution: execution, maximumIdentityBytes: maximumIdentityBytes)
        } catch { throw .runtime(error) }
    }

    private func base(_ system: StructuralMechanicalSystem, network: CompiledTransmissionNetwork,
        identity: String, policy: MechanismSolvePolicy, admission: DynamicsAdmission,
        maximumIdentityBytes: Int
    ) throws(StructuralSystemFailure) -> AffineMechanismEquation {
        do {
            return try AffineMechanismEquation(identity: identity, model: system.model,
                constraints: network.equations, drive: system.drive, policy: policy,
                admission: admission, maximumIdentityBytes: maximumIdentityBytes)
        } catch { throw .mechanism(error) }
    }
}

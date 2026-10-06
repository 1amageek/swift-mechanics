/// A kind-specific child endpoint; local/external identity is always explicit.
public struct BodyReference: Machine {
    public let reference: MachineEntityReference
    public init(_ reference: MachineEntityReference) { self.reference = reference }
    public var body: Never { fatalError("Reference lowering must not evaluate body.") }

    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        guard context.structuralEnabled, context.structuralChildToWorld != nil else {
            throw .compilation(.one(.invalidInput, .input,
                message: "BodyReference requires one nested joint child endpoint slot."))
        }
        guard context.structuralChildCount == 0 else {
            throw .compilation(.one(.invalidInput, .input,
                message: "A nested joint accepts exactly one direct child endpoint."))
        }
        let id = try context.resolve(reference)
        guard id.kind == .body else { throw .invalidJoint(.identityKindMismatch) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Forward BodyReference declarations enter here.
        // The current structural collector resolves admitted spatial bodies only; complete
        // deferred collection and original reference-order evidence are required before success.
        guard let body = context.bodies.first(where: { $0.id == id }) else {
            throw .compilation(.one(.unsupportedCapability, .topology, records: [id],
                message: "Forward structural body references are not implemented."))
        }
        guard body.dimension == .spatial else {
            throw .compilation(.one(.unsupportedCapability, .topology, records: [id],
                message: "This structural body reference requires a spatial endpoint."))
        }
        context.structuralChild = id; context.structuralChildCount = 1
    }
}

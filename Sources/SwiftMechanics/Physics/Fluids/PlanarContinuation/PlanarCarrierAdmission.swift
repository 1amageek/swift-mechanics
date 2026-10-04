
internal struct PlanarCarrierAdmission {
    static func validate(_ model: CompiledMechanicalModel, codec: any PlanarContinuationCoding,
                         work: inout PlanarContinuationWork) throws(PlanarContinuationError) {
        try work.charge(12)
        guard model.descriptor.bodies.count == 1, model.descriptor.joints.isEmpty, model.tree.joints.isEmpty,
              model.descriptor.rootBase == .fixed, model.descriptor.rootAuthority == .fixed,
              model.descriptor.initialState.q.isEmpty, model.descriptor.initialState.v.isEmpty,
              model.descriptor.initialState.acceleration.isEmpty else { throw .runtime(.incompatibleModel) }
        guard case .spatial(let body) = model.descriptor.bodies[0], body.mode == .static else {
            throw .runtime(.incompatibleModel)
        }
        var remaining = codec.grid.limits.maximumMetadataBytes
        try work.metadata(model.stamp.identity, remaining: &remaining)
        try work.metadata(model.descriptor.worldFrame.key, remaining: &remaining)
        try work.metadata(model.descriptor.root.key, remaining: &remaining)
        try work.metadata(body.id.key, remaining: &remaining)
        try work.metadata(body.frame.key, remaining: &remaining)
        guard model.stamp.revision == codec.model.revision,
              model.stamp.identity.utf8.elementsEqual(codec.model.identity.utf8),
              model.descriptor.worldFrame == codec.grid.frame,
              model.descriptor.worldFrame.key.utf8.elementsEqual(codec.grid.frame.key.utf8),
              model.descriptor.root == body.id else { throw .runtime(.incompatibleModel) }
        try work.poll()
    }
}

internal enum GranularRuntimeCarrier {
    static func validate(_ model: CompiledMechanicalModel,source: GranularRuntimeSource,work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try source.poll(work);try work.charge(32)
        var count=0
        for text in [model.stamp.identity,model.descriptor.worldFrame.key] {
            for _ in text.utf8 { try work.charge(3);guard count < source.maximumMetadataBytes else { throw .capacityExceeded };count+=1 }
        }
        guard model.stamp == source.carrier,model.descriptor.worldFrame == source.initial.model.frame.id,
              model.descriptor.bodies.count == 1,model.descriptor.joints.isEmpty,model.tree.joints.isEmpty,
              model.descriptor.rootBase == .fixed,model.descriptor.rootAuthority == .fixed,
              model.descriptor.initialState.q.isEmpty,model.descriptor.initialState.v.isEmpty,
              model.descriptor.initialState.acceleration.isEmpty,model.descriptor.initialState.prescribedAnchors.isEmpty else { throw .runtime(RuntimeFailure(.incompatibleModel,message:"Granular journal requires its same fixed-frame zero-coordinate carrier.")) }
        guard case .spatial(let body)=model.descriptor.bodies[0],body.mode == .static,model.descriptor.root == body.id else {
            throw .runtime(RuntimeFailure(.incompatibleModel,message:"Granular carrier must contain only its static root."))
        }
    }
}

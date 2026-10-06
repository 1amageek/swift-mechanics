internal enum RollingArithmetic {
    static func check(_ policy: RollingEvaluationPolicy) throws(RollingError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }

    static func finite(_ value: Double) throws(RollingError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }

    static func reserve(_ relation: RollingRelation, sample: RollingPrescribedPlaneSample?,
                        policy: RollingEvaluationPolicy, work: inout NumericalWork) throws {
        let tree = relation.model.tree, count = tree.layout.velocityCount
        var metadataBytes = 0
        func identifier(_ value: String) throws {
            metadataBytes = try NumericalWork.sum(metadataBytes, value.utf8.count)
        }
        try identifier(relation.sourceID); try identifier(relation.model.stamp.identity)
        try identifier(tree.worldFrame.key); try identifier(relation.wheel.body.key); try identifier(relation.wheel.frame.key)
        switch relation.plane {
        case .body(let body, let frame, _, _): try identifier(body.key); try identifier(frame.key)
        case .prescribed(let frame, let sourceID, _, _, _): try identifier(frame.key); try identifier(sourceID)
        }
        if let sample {
            try identifier(sample.sourceID); try identifier(sample.modelStamp.identity)
            try identifier(sample.frame.key); try identifier(sample.worldFrame.key)
        }
        guard metadataBytes <= policy.maximumMetadataBytes else { throw RollingError.capacityExceeded }
        let width = try NumericalWork.sum(count, 1)
        // Dense snapshot columns and owned output/work arrays coexist. This conservative scalar
        // reservation is independent of allocator byte measurements and includes all local phases.
        let treeStorage = try NumericalWork.product(256, NumericalWork.product(tree.bodies.count, width))
        let localStorage = try NumericalWork.product(128, width)
        let coordinateStorage = try NumericalWork.product(32, NumericalWork.sum(tree.layout.positionCount, count))
        let storage = try NumericalWork.sum(treeStorage, NumericalWork.sum(localStorage, coordinateStorage))
        try work.requireStorage(storage)
        // Compiled evaluate delegates once to the inspected tree/manifold kernels. No budget
        // supplier is recursively charged here; charge a bounded operation reservation up front.
        let operations = try NumericalWork.product(4096, NumericalWork.sum(
            NumericalWork.product(tree.bodies.count, width), NumericalWork.sum(width, tree.layout.positionCount)))
        try work.chargeOperations(operations)
        try check(policy)
    }
}

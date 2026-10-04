/// Bounds identity bytes before source equality, hashing or physical association.
internal enum StabilityMetadataAdmission {
    typealias Cause = NonlinearStabilityFailure.Cause
    @inline(never)
    static func validate(model: StaticForceModel, compiled: CompiledMechanicalModel, branch: EquilibriumBranch,
                         limit: Int, work: inout NumericalWork) throws(Cause) {
        try key(model.identity,limit:limit,work:&work)
        try key(model.parameterIdentity,limit:limit,work:&work)
        try key(branch.identity,limit:limit,work:&work)
        try key(model.chart.stamp.identity,limit:limit,work:&work)
        try key(model.chart.frame.key,limit:limit,work:&work)
        for joint in model.chart.joints { try key(joint.key,limit:limit,work:&work) }
        try key(compiled.stamp.identity,limit:limit,work:&work)
        let d=compiled.descriptor
        try key(d.identity,limit:limit,work:&work)
        try key(d.root.key,limit:limit,work:&work)
        try key(d.worldFrame.key,limit:limit,work:&work)
        for body in d.bodies {
            try key(body.id.key,limit:limit,work:&work)
            switch body {
            case .spatial(let record):
                try key(record.frame.key,limit:limit,work:&work)
                if let inertia=record.inertia { try key(inertia.provenance.source,limit:limit,work:&work) }
                try geometry(record.representations,limit:limit,work:&work)
            case .planar(let record):
                try key(record.frame.key,limit:limit,work:&work)
                if let inertia=record.inertia { try key(inertia.provenance.source,limit:limit,work:&work) }
                try geometry(record.representations,limit:limit,work:&work)
            }
        }
        for joint in d.joints { try record(joint.record,limit:limit,work:&work) }
        for item in d.representationRequirements { try key(item.body.key,limit:limit,work:&work) }
        for item in d.features { try key(item.feature,limit:limit,work:&work) }
        for item in d.extensions {
            try key(item.id.key,limit:limit,work:&work);try key(item.schema,limit:limit,work:&work)
            for reference in item.references { try key(reference.key,limit:limit,work:&work) }
            for parameter in item.parameters { try key(parameter.name,limit:limit,work:&work) }
        }
        try key(compiled.tree.worldFrame.key,limit:limit,work:&work)
        for body in compiled.tree.bodies {
            try key(body.id.key,limit:limit,work:&work);try key(body.frame.key,limit:limit,work:&work)
        }
        for joint in compiled.tree.joints { try record(joint,limit:limit,work:&work) }
        for item in compiled.manifest.entries {
            try key(item.requirement.feature,limit:limit,work:&work);try key(item.owner,limit:limit,work:&work)
            try key(item.evidenceRevision,limit:limit,work:&work)
        }
        for item in compiled.manifest.producerEvidence {
            try key(item.owner,limit:limit,work:&work);try key(item.revision,limit:limit,work:&work)
        }
        for item in compiled.validatorRegistrations {
            try key(item.schema,limit:limit,work:&work);try key(item.feature,limit:limit,work:&work)
            try key(item.owner,limit:limit,work:&work);try key(item.evidenceRevision,limit:limit,work:&work)
        }
        for item in compiled.cacheDependencies {
            if let entity=item.cache.entity { try key(entity.key,limit:limit,work:&work) }
            for input in item.inputs { if let entity=input.entity { try key(entity.key,limit:limit,work:&work) } }
        }
        for item in compiled.extensionEvidence {
            try key(item.feature,limit:limit,work:&work)
            for input in item.dependencies { if let entity=input.entity { try key(entity.key,limit:limit,work:&work) } }
        }
    }
    private static func record(_ joint: JointRecord, limit: Int, work: inout NumericalWork) throws(Cause) {
        try key(joint.id.key,limit:limit,work:&work);try key(joint.parentBody.key,limit:limit,work:&work)
        try key(joint.childBody.key,limit:limit,work:&work);try key(joint.parentAnchor.frame.key,limit:limit,work:&work)
        try key(joint.childAnchor.frame.key,limit:limit,work:&work)
    }
    private static func geometry(_ representations: BodyRepresentations, limit: Int, work: inout NumericalWork) throws(Cause) {
        for item in [representations.geometricShape,representations.displayGeometry,representations.collisionGeometry] {
            if let item { try key(item.assetKey,limit:limit,work:&work);try key(item.provenance.source,limit:limit,work:&work) }
        }
    }
    private static func key(_ value: String, limit: Int, work: inout NumericalWork) throws(Cause) {
        var consumed=0
        // Borrow the UTF-8 view: no unbounded count, conversion or copy precedes admission.
        for _ in value.utf8 {
            guard !Task.isCancelled else { throw .cancelled }
            try StabilityArithmetic.charge(1,&work)
            guard consumed<limit else { throw .capacityExceeded }
            consumed+=1
        }
        guard consumed>0 else { throw .invalidInput }
    }
}

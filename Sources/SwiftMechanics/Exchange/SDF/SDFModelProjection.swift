internal struct SDFModelProjection {
    var admission: SDFAdmission

    mutating func descriptor(_ top: String, work: inout SDFWork) throws -> MechanicalDescriptor {
        let source = admission.options.source, declarations = admission.declarations
        var bodies: [MechanicalBody] = [], links: [Int] = [], joints: [MechanicalJoint] = []
        var parentCounts: [Int: Int] = [:], freeCoordinates = 0
        try work.comparisons(declarations.count * 2)
        for index in declarations.indices where declarations[index].top == top && declarations[index].kind == .link {
            try work.row(); try work.charge(240)
            let declaration = declarations[index]
            let inertia = try suppliedInertia(declaration.node, work: &work)
            if !declaration.staticModel, inertia == nil { throw SDFError.missing(element: "explicit dynamic inertia", node: declaration.node) }
            let record = try BodyRecord3D(id: bodyID(declaration.name), frame: frameID(declaration.name),
                mode: declaration.staticModel ? .static : .dynamic, bodyToWorld: admission.poses[index],
                representations: BodyRepresentations(), inertia: inertia)
            bodies.append(.spatial(record)); links.append(index); parentCounts[index] = 0
        }
        guard !links.isEmpty else { throw SDFError.invalidTopology(top) }
        for index in declarations.indices where declarations[index].top == top && declarations[index].kind == .joint {
            try work.row(); try work.charge(360)
            let declaration = declarations[index], node = declaration.node, nodes = admission.nodes
            let parentName = try admission.reference(node, "parent", work: &work)
            let childName = try admission.reference(node, "child", work: &work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): SDF world-parent joints are not mapped to root constraint authority.
            // decode reaches this branch; a qualified root-constraint mapping is required before this domain may publish.
            guard parentName != "world" else { throw SDFError.unsupported(element: "world-parent joint", node: node) }
            let parent = try admission.lookup(parentName, scope: declaration.scope, work: &work)
            let child = try admission.lookup(childName, scope: declaration.scope, work: &work)
            guard parent != child, parent >= 0, child >= 0,
                  declarations[parent].kind == .link, declarations[child].kind == .link,
                  declarations[parent].top == top, declarations[child].top == top,
                  let parents = parentCounts[child], parents == 0 else { throw SDFError.invalidTopology(declaration.name) }
            parentCounts[child] = 1
            let type = try nodes.attribute(node, "type", work: &work) ?? ""
            let specification: JointSpecification
            if type == "fixed" {
                guard try nodes.single(node, "axis", work: &work) == nil else { throw SDFError.unsupported(element: "fixed joint axis", node: node) }
                specification = .fixed
            } else {
                guard !declaration.staticModel else { throw SDFError.unsupported(element: "static continuous joint", node: node) }
                guard let axis = try nodes.single(node, "axis", required: true, work: &work),
                      let xyz = try nodes.single(axis, "xyz", required: true, work: &work) else { throw SDFError.missing(element: "axis/xyz", node: node) }
                try nodes.checked(axis, attributes: [], work: &work)
                try nodes.checked(xyz, attributes: ["expressed_in"], work: &work)
                for extra in try nodes.elements(axis, work: &work) where nodes.name(extra) != "xyz" { try admission.unserved(extra, work: &work) }
                let values = try SDFNumbers.values(nodes.text(xyz, work: &work), maximum: 3, node: xyz, work: &work)
                guard values.count == 3 else { throw SDFError.invalidInput(node: xyz) }
                let original = try Vector3(values[0], values[1], values[2])
                guard try admission.compilation.rotationTolerance.contains(error: original.magnitude() - 1, scale: 1) else { throw SDFError.invalidInput(node: xyz) }
                let expressed = try nodes.attribute(xyz, "expressed_in", work: &work) ?? ""
                let sourcePose: RigidTransform
                if expressed.isEmpty { sourcePose = admission.poses[index] }
                else {
                    let frame = try admission.lookup(expressed, scope: declaration.scope, work: &work)
                    sourcePose = frame < 0 ? .identity : admission.poses[frame]
                }
                let worldAxis = try sourcePose.transforming(direction: original)
                let localAxis = try admission.poses[index].inverted().transforming(direction: worldAxis)
                specification = .revolute(axis: localAxis); freeCoordinates += 1
            }
            let parentPlacement = try admission.poses[parent].inverted().composed(with: admission.poses[index])
            let childPlacement = try admission.poses[child].inverted().composed(with: admission.poses[index])
            let record = try JointRecord(id: EntityID(kind: .joint, key: admission.options.identity + ":joint:" + declaration.name),
                parentBody: bodyID(declarations[parent].name), childBody: bodyID(declarations[child].name),
                parentAnchor: JointAnchor(frame: anchorID(declaration.name, "parent"), placement: .fixed(parentPlacement)),
                childAnchor: JointAnchor(frame: anchorID(declaration.name, "child"), placement: .fixed(childPlacement)),
                manifold: JointManifold(specification))
            joints.append(MechanicalJoint(record: record, authority: type == "fixed" ? .fixed : .dynamicState))
        }
        let roots = links.filter { parentCounts[$0] == 0 }
        guard roots.count == 1, joints.count == links.count - 1 else { throw SDFError.invalidTopology(top) }
        let root = roots[0], fixed = declarations[root].staticModel
        let base: BaseLayout = fixed ? .fixed : .spatialFloating
        let coordinates = try base.encode(fixed ? .fixed : .spatial(pose: admission.poses[root],
            worldLinearVelocity: .zero, bodyAngularVelocity: .zero))
        var q = coordinates.q, v = coordinates.v
        q.append(contentsOf: repeatElement(0, count: freeCoordinates))
        v.append(contentsOf: repeatElement(0, count: freeCoordinates))
        let state = try KinematicState(revision: source.revision, time: admission.options.time, q: q, v: v, acceleration: v)
        return try MechanicalDescriptor(identity: admission.options.identity + ":model:" + top, revision: source.revision,
            bodies: bodies, joints: joints, root: bodyID(declarations[root].name), rootBase: base,
            rootAuthority: fixed ? .fixed : .dynamicState, worldFrame: admission.options.worldFrame, initialState: state,
            representationRequirements: [], features: [], extensions: [])
    }

    func bodyID(_ name: String) throws -> EntityID {
        try EntityID(kind: .body, key: admission.options.identity + ":body:" + name)
    }
    func frameID(_ name: String) throws -> EntityID {
        try EntityID(kind: .frame, key: admission.options.identity + ":frame:" + name)
    }
    func anchorID(_ name: String, _ side: String) throws -> EntityID {
        try EntityID(kind: .frame, key: admission.options.identity + ":anchor:" + side + ":" + name)
    }

    private func suppliedInertia(_ link: Int, work: inout SDFWork) throws -> InertialRepresentation3D? {
        let nodes = admission.nodes
        guard let node = try nodes.single(link, "inertial", work: &work) else { return nil }
        try nodes.checked(node, attributes: ["auto"], work: &work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): SDF automatic geometry-derived inertia is absent.
        // decode reaches this branch; only explicit physically validated mass/COM/tensor may publish until a geometry authority supplies computation.
        if let auto = try nodes.attribute(node, "auto", work: &work), auto != "false", auto != "0" {
            throw SDFError.unsupported(element: "auto inertia", node: node)
        }
        for child in try nodes.elements(node, work: &work) where !["mass", "inertia", "pose"].contains(nodes.name(child)) {
            throw SDFError.unsupported(element: nodes.name(child), node: child)
        }
        guard let mass = try nodes.single(node, "mass", required: true, work: &work),
              let tensor = try nodes.single(node, "inertia", required: true, work: &work) else { throw SDFError.missing(element: "explicit mass/inertia", node: node) }
        try nodes.checked(tensor, attributes: [], work: &work)
        let fields = ["ixx", "ixy", "ixz", "iyy", "iyz", "izz"]
        for extra in try nodes.elements(tensor, work: &work) where !fields.contains(nodes.name(extra)) { throw SDFError.unsupported(element: nodes.name(extra), node: extra) }
        var values: [Double] = []
        for field in fields {
            guard let value = try nodes.single(tensor, field, required: true, work: &work) else { throw SDFError.missing(element: field, node: tensor) }
            values.append(try admission.scalar(value, work: &work))
        }
        let matrix = try Matrix3(values[0], values[1], values[2], values[1], values[3], values[4], values[2], values[4], values[5])
        let supplied = try MassProperties3D(mass: admission.scalar(mass, work: &work), centerOfMass: .zero,
                                           inertiaAtCenter: matrix, policy: admission.compilation.inertiaPolicy)
        let pose = try admission.pose(node, allowedRelative: false, work: &work).0
        return InertialRepresentation3D(properties: try supplied.transformed(by: pose, policy: admission.compilation.inertiaPolicy),
                                       provenance: admission.options.source, quality: admission.options.inertiaQuality)
    }
}

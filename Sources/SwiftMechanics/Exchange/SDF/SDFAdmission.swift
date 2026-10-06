internal struct SDFAdmission {
    let nodes: SDFNodes
    let options: SDFImportOptions
    let compilation: CompilationPolicy
    var declarations: [SDFDeclaration] = []
    var losses: [SDFLoss] = []
    var assets: [SDFAssetReference] = []
    var poses: [RigidTransform] = []
    var poseParents: [Int] = []
    var attachments: [Int] = []
    var worldName: String?
    var gravity: Vector3 = .zero

    mutating func collect(work: inout SDFWork) throws {
        let root = nodes.document.rootIndex
        guard nodes.name(root) == "sdf" else { throw SDFError.invalidInput(node: root) }
        try nodes.checked(root, attributes: ["version"], work: &work)
        let version = try nodes.attribute(root, "version", work: &work) ?? ""
        guard version == "1.12" else { throw SDFError.unsupportedVersion(version) }
        let roots = try nodes.elements(root, work: &work)
        guard !roots.isEmpty else { throw SDFError.missing(element: "model/world", node: root) }
        var scopeRoot = root
        if roots.count == 1, nodes.name(roots[0]) == "world" {
            scopeRoot = roots[0]
            try nodes.checked(scopeRoot, attributes: ["name"], work: &work)
            guard let label = try nodes.attribute(scopeRoot, "name", work: &work), !label.isEmpty,
                  label.utf8.count <= work.policy.maximumTokenBytes else { throw SDFError.invalidInput(node: scopeRoot) }
            worldName = label
            if let value = try nodes.single(scopeRoot, "gravity", work: &work) {
                try nodes.checked(value, attributes: [], work: &work)
                let values = try SDFNumbers.values(nodes.text(value, work: &work), maximum: 3, node: value, work: &work)
                guard values.count == 3 else { throw SDFError.invalidInput(node: value) }
                gravity = try Vector3(values[0], values[1], values[2])
            } else { gravity = try Vector3(0, 0, -9.8) }
        } else {
            guard roots.count == 1, nodes.name(roots[0]) == "model" else { throw SDFError.unsupported(element: "multiple worlds/standalone models", node: root) }
            gravity = options.standaloneGravity
        }
        var pending: [(node: Int, scope: String, top: String, inheritedStatic: Bool?)] = []
        for node in try nodes.elements(scopeRoot, work: &work) {
            let name = nodes.name(node)
            if name == "model" { pending.append((node, "", "", nil)) }
            else if name == "frame", scopeRoot != root { try add(node, .frame, "", "", false, work: &work) }
            else if name != "gravity" { try unserved(node, work: &work) }
        }
        var position = 0
        while position < pending.count {
            try work.row()
            let item = pending[position]; position += 1
            try nodes.checked(item.node, attributes: ["name", "canonical_link"], work: &work)
            let localName = try named(item.node, work: &work)
            let fullName = try qualified(item.scope, localName, work: &work)
            let top = item.top.isEmpty ? fullName : item.top
            let staticNode = try nodes.single(item.node, "static", work: &work)
            let explicitStatic: Bool
            if let staticNode { explicitStatic = try boolean(staticNode, work: &work) }
            else { explicitStatic = item.inheritedStatic ?? false }
            guard item.inheritedStatic == nil || item.inheritedStatic == explicitStatic else {
                throw SDFError.unsupported(element: "mixed nested static authority", node: item.node)
            }
            try add(item.node, .model, item.scope, top, explicitStatic, work: &work)
            for child in try nodes.elements(item.node, work: &work) {
                switch nodes.name(child) {
                case "model": pending.append((child, fullName, top, explicitStatic))
                case "link": try add(child, .link, fullName, top, explicitStatic, work: &work)
                case "joint": try add(child, .joint, fullName, top, explicitStatic, work: &work)
                case "frame": try add(child, .frame, fullName, top, explicitStatic, work: &work)
                case "pose", "static": break
                default: try unserved(child, work: &work)
                }
            }
        }
        try work.comparisons(declarations.count)
        guard declarations.contains(where: { $0.kind == .model && $0.scope.isEmpty }) else { throw SDFError.missing(element: "model", node: root) }
        for record in declarations {
            switch record.kind {
            case .link:
                try nodes.checked(record.node, attributes: ["name"], work: &work)
                for child in try nodes.elements(record.node, work: &work) where !["pose", "inertial"].contains(nodes.name(child)) {
                    try unserved(child, work: &work)
                }
                _ = try nodes.single(record.node, "inertial", work: &work)
            case .joint:
                try nodes.checked(record.node, attributes: ["name", "type"], work: &work)
                let type = try nodes.attribute(record.node, "type", work: &work) ?? ""
                // FIXME(INCOMPLETE_IMPLEMENTATION): Other SDF joint kinematics/world anchoring are absent.
                // decode reaches this branch; only qualified fixed/continuous tree mapping may publish before additional laws/topology are implemented.
                guard type == "fixed" || type == "continuous" else { throw SDFError.unsupported(element: "joint type " + type, node: record.node) }
                for child in try nodes.elements(record.node, work: &work) where !["pose", "parent", "child", "axis"].contains(nodes.name(child)) {
                    try unserved(child, work: &work)
                }
            case .frame:
                try nodes.checked(record.node, attributes: ["name", "attached_to"], work: &work)
                for child in try nodes.elements(record.node, work: &work) where nodes.name(child) != "pose" {
                    throw SDFError.unsupported(element: nodes.name(child), node: child)
                }
            case .model: break
            }
        }
        try resolve(work: &work)
    }

    mutating func add(_ node: Int, _ kind: SDFDeclaration.Kind, _ scope: String, _ top: String,
                      _ staticModel: Bool, work: inout SDFWork) throws {
        guard declarations.count < work.policy.maximumNamedRecords else { throw SDFError.invalidInput(node: node) }
        let name = try qualified(scope, named(node, work: &work), work: &work)
        for other in declarations {
            try work.inspect(name); try work.inspect(other.name)
            guard other.name != name else { throw SDFError.duplicateName(name) }
        }
        declarations.append(SDFDeclaration(node: node, kind: kind, name: name, scope: scope, top: top, staticModel: staticModel))
    }

    func named(_ node: Int, work: inout SDFWork) throws -> String {
        guard let value = try nodes.attribute(node, "name", work: &work), !value.isEmpty,
              value.utf8.count <= work.policy.maximumTokenBytes,
              !value.contains("::"), !value.contains(where: { $0.isWhitespace }),
              value != "world", value != "__model__" else { throw SDFError.invalidInput(node: node) }
        return value
    }

    func qualified(_ scope: String, _ name: String, work: inout SDFWork) throws -> String {
        try work.inspect(scope); try work.inspect(name)
        let result = scope.isEmpty ? name : scope + "::" + name
        guard result.utf8.count <= work.policy.maximumTokenBytes else { throw SDFError.invalidInput(node: 0) }
        return result
    }

    func lookup(_ reference: String, scope: String, allowWorld: Bool = false, work: inout SDFWork) throws -> Int {
        try work.inspect(reference)
        if reference == "world" {
            guard scope.isEmpty || allowWorld else { throw SDFError.unknownFrame(reference) }
            return -1
        }
        let name = reference == "__model__" ? scope : try qualified(scope, reference, work: &work)
        for (index, declaration) in declarations.enumerated() {
            try work.inspect(declaration.name); try work.inspect(name)
            if declaration.name == name { return index }
        }
        throw SDFError.unknownFrame(name)
    }

    func scalar(_ node: Int, work: inout SDFWork) throws -> Double {
        try nodes.checked(node, attributes: [], work: &work)
        let values = try SDFNumbers.values(nodes.text(node, work: &work), maximum: 1, node: node, work: &work)
        guard values.count == 1 else { throw SDFError.invalidInput(node: node) }; return values[0]
    }

    func boolean(_ node: Int, work: inout SDFWork) throws -> Bool {
        try nodes.checked(node, attributes: [], work: &work)
        let text = try SDFNumbers.word(nodes.text(node, work: &work), node: node, work: &work)
        if text == "true" || text == "1" { return true }
        if text == "false" || text == "0" { return false }
        throw SDFError.invalidInput(node: node)
    }

    func reference(_ parent: Int, _ child: String, work: inout SDFWork) throws -> String {
        guard let node = try nodes.single(parent, child, required: true, work: &work) else { throw SDFError.missing(element: child, node: parent) }
        try nodes.checked(node, attributes: [], work: &work)
        return try SDFNumbers.word(nodes.text(node, work: &work), node: node, work: &work)
    }

    func pose(_ parent: Int, allowedRelative: Bool = true, work: inout SDFWork) throws -> (RigidTransform, String?) {
        guard let node = try nodes.single(parent, "pose", work: &work) else { return (.identity, nil) }
        try nodes.checked(node, attributes: allowedRelative ? ["relative_to", "rotation_format", "degrees"] : ["rotation_format", "degrees"], work: &work)
        if let degrees = try nodes.attribute(node, "degrees", work: &work), degrees != "false", degrees != "0" {
            throw SDFError.unsupported(element: "degrees pose", node: node)
        }
        let format = try nodes.attribute(node, "rotation_format", work: &work) ?? "euler_rpy"
        guard format == "euler_rpy" || format == "quat_xyzw" else { throw SDFError.unsupported(element: "pose rotation format", node: node) }
        let values = try SDFNumbers.values(nodes.text(node, work: &work), maximum: 7, node: node, work: &work)
        let relative = try nodes.attribute(node, "relative_to", work: &work)
        if values.isEmpty { return (.identity, relative) }
        let rotation: UnitQuaternion
        if format == "euler_rpy", values.count == 6 {
            let roll = try UnitQuaternion(axis: .unitX, angle: values[3])
            let pitch = try UnitQuaternion(axis: .unitY, angle: values[4])
            let yaw = try UnitQuaternion(axis: .unitZ, angle: values[5])
            rotation = try yaw.multiplied(by: pitch).multiplied(by: roll)
        } else if format == "quat_xyzw", values.count == 7 {
            rotation = try UnitQuaternion(unitW: values[6], x: values[3], y: values[4], z: values[5])
        } else { throw SDFError.unsupported(element: "pose rotation format", node: node) }
        return (RigidTransform(rotation: rotation, translation: try Vector3(values[0], values[1], values[2])), relative)
    }

    mutating func resolve(work: inout SDFWork) throws {
        let count = declarations.count
        var local: [RigidTransform] = [], dependencies: [Int] = [], attachment: [Int] = []
        local.reserveCapacity(count); dependencies.reserveCapacity(count); attachment.reserveCapacity(count)
        for record in declarations {
            try work.row()
            try work.comparisons(count * 2)
            let sample = try pose(record.node, work: &work)
            let scopeFrame = record.scope.isEmpty ? -1 : try lookup("__model__", scope: record.scope, work: &work)
            let attached: Int
            let defaultPose: Int
            switch record.kind {
            case .link: attached = -2; defaultPose = scopeFrame
            case .joint:
                let child = try reference(record.node, "child", work: &work)
                attached = try lookup(child, scope: record.scope, work: &work)
                guard attached >= 0, declarations[attached].kind == .link else { throw SDFError.invalidTopology(record.name) }
                defaultPose = attached
            case .frame:
                let name = try nodes.attribute(record.node, "attached_to", work: &work) ?? ""
                if name.isEmpty { attached = scopeFrame }
                else {
                    guard !name.contains("::") else { throw SDFError.unsupported(element: "nested attached_to", node: record.node) }
                    attached = try lookup(name, scope: record.scope, work: &work)
                }
                defaultPose = attached
            case .model:
                defaultPose = scopeFrame
                if record.staticModel { attached = -1 }
                else if let canonical = try nodes.attribute(record.node, "canonical_link", work: &work), !canonical.isEmpty {
                    attached = try lookup(canonical, scope: record.name, work: &work)
                    guard declarations[attached].kind == .link else { throw SDFError.invalidTopology(record.name) }
                } else {
                    let direct = declarations.firstIndex(where: { $0.scope == record.name && $0.kind == .link })
                    let nested = declarations.firstIndex(where: { $0.scope == record.name && $0.kind == .model })
                    guard let canonical = direct ?? nested else { throw SDFError.invalidTopology(record.name) }
                    attached = canonical
                }
            }
            let relative: Int
            if let name = sample.1, !name.isEmpty { relative = try lookup(name, scope: record.scope, work: &work) }
            else { relative = defaultPose }
            local.append(sample.0); dependencies.append(relative); attachment.append(attached)
        }
        var resolved = [RigidTransform?](repeating: nil, count: count)
        for start in declarations.indices {
            try work.row()
            var path: [Int] = [], current = start
            while current >= 0, resolved[current] == nil {
                try work.charge(count + 2)
                guard !path.contains(current) else { throw SDFError.poseCycle(declarations[current].name) }
                path.append(current); current = dependencies[current]
            }
            var parent = RigidTransform.identity
            if current >= 0 {
                guard let value = resolved[current] else { throw SDFError.poseCycle(declarations[current].name) }
                parent = value
            }
            while let index = path.popLast() {
                try work.charge(120)
                parent = try parent.composed(with: local[index]); resolved[index] = parent
            }
        }
        var owners = [Int](repeating: -3, count: count)
        for start in declarations.indices {
            try work.row()
            var path: [Int] = [], current = start
            while current >= 0, owners[current] == -3 {
                try work.charge(count + 2)
                guard !path.contains(current) else { throw SDFError.attachmentCycle(declarations[current].name) }
                path.append(current)
                if attachment[current] == -2 { owners[current] = current; break }
                current = attachment[current]
            }
            let owner = current < 0 ? -1 : owners[current]
            for index in path { owners[index] = owner }
        }
        self.poses = try resolved.enumerated().map {
            guard let pose = $0.element else { throw SDFError.poseCycle(declarations[$0.offset].name) }; return pose
        }
        self.poseParents = dependencies; self.attachments = owners
    }

    mutating func unserved(_ node: Int, work: inout SDFWork) throws {
        let name = nodes.name(node)
        // FIXME(INCOMPLETE_IMPLEMENTATION): External includes, alternate placement and engine/geometry/sensor/law execution are absent.
        // decode reaches this branch; selected retained XML is an explicit loss, and must never certify these operations as executed.
        guard !["include", "placement_frame", "spherical_coordinates", "state", "model_state"].contains(name),
              options.unservedRecords == .preserveOriginalWithExplicitLosses else {
            throw SDFError.unsupported(element: name, node: node)
        }
        losses.append(SDFLoss(element: name, node: node, reason: "Original record retained without an executable mechanics binding."))
        var pending = [node], position = 0
        while position < pending.count {
            try work.row()
            let current = pending[position]; position += 1
            if nodes.name(current) == "uri" || nodes.name(current) == "filename" {
                let path = try nodes.text(current, work: &work)
                try admitAsset(path, node: current, work: &work)
            }
            if case .element(_, let attributes) = nodes.document.nodes[current].content {
                for attribute in attributes where attribute.name == "filename" {
                    try admitAsset(attribute.value, node: current, work: &work)
                }
            }
            pending.append(contentsOf: nodes.children[current])
        }
    }

    mutating func admitAsset(_ path: String, node: Int, work: inout SDFWork) throws {
        guard let root = options.assetRoot, !path.isEmpty else { throw SDFError.assetRejected(path) }
        try work.inspect(path); try work.inspect(root.key)
        guard path.utf8.count <= work.policy.maximumAssetBytes, !path.contains("\\"),
              !path.contains("?"), !path.contains("#"), !path.contains("%"), !path.hasPrefix("/") else {
            throw SDFError.assetRejected(path)
        }
        var segmentLength = 0, dotsOnly = true
        for byte in path.utf8 {
            try work.charge(2)
            if byte == 47 {
                guard !(dotsOnly && segmentLength == 2) else { throw SDFError.assetRejected(path) }
                segmentLength = 0; dotsOnly = true
            } else { segmentLength += 1; dotsOnly = dotsOnly && byte == 46 }
        }
        guard !(dotsOnly && segmentLength == 2) else { throw SDFError.assetRejected(path) }
        var admittedPrefix = false
        for prefix in root.allowedPathPrefixes {
            try work.inspect(prefix); try work.inspect(path)
            if path.hasPrefix(prefix) { admittedPrefix = true }
        }
        guard admittedPrefix else { throw SDFError.assetRejected(path) }
        if let colon = path.firstIndex(of: ":") {
            let scheme = String(path[..<colon])
            var allowed = false
            for candidate in root.allowedSchemes {
                try work.inspect(candidate)
                if candidate == scheme { allowed = true }
            }
            guard allowed else { throw SDFError.assetRejected(path) }
        }
        assets.append(SDFAssetReference(originalPath: path, rootKey: root.key, source: options.source, node: node))
    }
}

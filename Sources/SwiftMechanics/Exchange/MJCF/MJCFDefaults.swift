internal struct MJCFDefaults {
    private var classes: [String: [String: [MJCFEffectiveAttribute]]] = ["main": [:]]
    init(table: MJCFElementTable, root: Int?, work: inout MJCFWork) throws(MJCFError) {
        guard let root else { return }
        try work.allocate(MemoryLayout<(Int,String)>.stride)
        var queue: [(Int, String)] = [(root, "main")], cursor = 0, names = Set<String>()
        while cursor < queue.count {
            try work.charge(1)
            let (node, parent) = queue[cursor]; cursor += 1
            guard cursor <= work.policy.maximumDefaults else { throw .capacityExceeded }
            let fields = try table.fields(node, work: &work)
            try MJCFElementTable.check(fields, allowed: ["class"], node: node, work: &work)
            let name = try MJCFElementTable.value(fields, "class", work: &work) ?? (node == root ? "main" : "")
            guard !name.isEmpty, node != root || name == "main", names.insert(name).inserted else { throw .duplicate(node: node, name: name) }
            guard let parentTemplates = classes[parent] else { throw .danglingReference(node: node, name: parent) }
            try work.allocate(try MJCFArithmetic.product(parentTemplates.count, MemoryLayout<(String,[MJCFEffectiveAttribute])>.stride))
            for (_, fields) in parentTemplates { try work.charge(fields.count) }
            var templates = parentTemplates, seen = Set<String>()
            for child in table.children[node] {
                let kind = table.name(child)
                if kind == "default" { try work.allocate(MemoryLayout<(Int,String)>.stride); queue.append((child, name)); continue }
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                guard let allowed = Self.fields(for: kind), seen.insert(kind).inserted, table.children[child].isEmpty else { throw .unsupported(node: child, feature: kind) }
                let explicit = try table.fields(child, work: &work)
                try MJCFElementTable.check(explicit, allowed: allowed, node: child, work: &work)
                try Self.validate(explicit, kind: kind, node: child, work: &work)
                templates[kind] = try Self.merge(templates[kind] ?? [], explicit, work: &work)
            }
            try work.allocate(MemoryLayout<(String,[String:[MJCFEffectiveAttribute]])>.stride)
            classes[name] = templates
        }
    }
    func effective(table: MJCFElementTable, node: Int, kind: String, activeClass: String, work: inout MJCFWork) throws(MJCFError) -> [MJCFEffectiveAttribute] {
        let explicit = try table.fields(node, work: &work)
        let name = try MJCFElementTable.value(explicit, "class", work: &work) ?? activeClass
        guard let templates = classes[name] else { throw .danglingReference(node: node, name: name) }
        return try Self.merge(templates[kind] ?? [], explicit, work: &work)
    }
    func contains(_ name: String) -> Bool { classes[name] != nil }
    private static func validate(_ fields: [MJCFEffectiveAttribute], kind: String, node: Int, work: inout MJCFWork) throws(MJCFError) {
        switch kind {
        case "joint":
            if let type = try MJCFElementTable.value(fields, "type", work: &work) {
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                guard type == "hinge" || type == "slide" else { throw .unsupported(node: node, feature: type) }
            }
            try MJCFBodyBuilder.unlimited(fields, node: node, work: &work)
            try MJCFBodyBuilder.passiveZero(fields, names: ["armature","damping","frictionloss","stiffness","springref"], node: node, work: &work)
        case "tendon":
            try MJCFBodyBuilder.unlimited(fields, node: node, work: &work)
            try MJCFBodyBuilder.passiveZero(fields, names: ["stiffness","damping","frictionloss"], node: node, work: &work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard try MJCFElementTable.value(fields, "springlength", work: &work) == nil else { throw .unsupported(node: node, feature: "springlength") }
        case "motor":
            for field in ["ctrllimited","forcelimited"] {
                // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                // This path must keep failing until its real provider and original behavioral evidence are available.
                if let value = try MJCFElementTable.value(fields, field, work: &work) { guard value == "false" || value == "auto" else { throw .unsupported(node: node, feature: field) } }
            }
            guard try MJCFElementTable.value(fields, "ctrlrange", work: &work) == nil,
                  // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                  // This path must keep failing until its real provider and original behavioral evidence are available.
                  try MJCFElementTable.value(fields, "forcerange", work: &work) == nil else { throw .unsupported(node: node, feature: "motor clamping") }
        case "equality":
            let p = try MJCFElementTable.numbers(fields, "polycoef", fallback: [0,1,0,0,0], count: 5, node: node, work: &work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
            // This path must keep failing until its real provider and original behavioral evidence are available.
            guard p[2] == 0, p[3] == 0, p[4] == 0 else { throw .unsupported(node: node, feature: "nonlinear equality default") }
            if let value = try MJCFElementTable.value(fields, "active", work: &work) { guard value == "true" else { throw .unsupported(node: node, feature: "inactive equality default") } }
        case "material":
            guard try MJCFElementTable.value(fields, "texture", work: &work) == nil,
                  try MJCFElementTable.value(fields, "texrepeat", work: &work) == nil,
                  // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported MJCF semantics at this gate.
                  // This path must keep failing until its real provider and original behavioral evidence are available.
                  try MJCFElementTable.value(fields, "texuniform", work: &work) == nil else { throw .unsupported(node: node, feature: "textured material default") }
        default: throw .unsupported(node: node, feature: kind)
        }
    }
    private static func merge(_ inherited: [MJCFEffectiveAttribute], _ explicit: [MJCFEffectiveAttribute], work: inout MJCFWork) throws(MJCFError) -> [MJCFEffectiveAttribute] {
        try work.allocate(try MJCFArithmetic.product(try MJCFArithmetic.sum(inherited.count, explicit.count), MemoryLayout<MJCFEffectiveAttribute>.stride))
        var result: [MJCFEffectiveAttribute] = []
        for old in inherited {
            var overridden = false
            for field in explicit { try work.charge(1); if field.name == old.name { overridden = true } }
            if !overridden { result.append(MJCFEffectiveAttribute(name: old.name, value: old.value, definingNode: old.definingNode, inherited: true)) }
        }
        for field in explicit { try work.charge(1); result.append(field) }; return result
    }
    static func fields(for kind: String) -> [String]? {
        switch kind {
        case "joint": ["type","pos","axis","ref","limited","range","armature","damping","frictionloss","stiffness","springref"]
        case "motor": ["gear","ctrllimited","forcelimited","ctrlrange","forcerange"]
        case "tendon": ["limited","range","stiffness","damping","frictionloss","springlength","width","rgba","material"]
        case "equality": ["active","polycoef","solref","solimp"]
        case "material": ["rgba","emission","specular","shininess","reflectance","texture","texrepeat","texuniform"]
        default: nil
        }
    }
}

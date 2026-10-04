
internal enum NativeWireTags {
    static func entityKind(_ value:EntityKind) -> UInt8 {
        switch value { case .body: 0; case .frame: 1; case .joint: 2; case .collider: 3; case .material: 4; case .load: 5; case .actuator: 6; case .sensor: 7 }
    }
    static func entityKind(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> EntityKind {
        switch tag { case 0: return .body; case 1: return .frame; case 2: return .joint; case 3: return .collider; case 4: return .material; case 5: return .load; case 6: return .actuator; case 7: return .sensor; default: throw .unknownTag(offset:offset) }
    }
    static func bodyMode(_ value:BodyMotionMode) -> UInt8 {
        switch value { case .static: 0; case .prescribedKinematic: 1; case .dynamic: 2 }
    }
    static func bodyMode(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> BodyMotionMode {
        switch tag { case 0: return .static; case 1: return .prescribedKinematic; case 2: return .dynamic; default: throw .unknownTag(offset:offset) }
    }
    static func baseLayout(_ value:BaseLayout) -> UInt8 {
        switch value { case .fixed: 0; case .planarFloating: 1; case .spatialFloating: 2 }
    }
    static func baseLayout(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> BaseLayout {
        switch tag { case 0: return .fixed; case 1: return .planarFloating; case 2: return .spatialFloating; default: throw .unknownTag(offset:offset) }
    }
    static func authority(_ value:CoordinateAuthority) -> UInt8 {
        switch value { case .fixed: 0; case .dynamicState: 1; case .prescribedMotion: 2 }
    }
    static func authority(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> CoordinateAuthority {
        switch tag { case 0: return .fixed; case 1: return .dynamicState; case 2: return .prescribedMotion; default: throw .unknownTag(offset:offset) }
    }
    static func representationKind(_ value:RepresentationKind) -> UInt8 {
        switch value { case .geometricShape: 0; case .displayGeometry: 1; case .collisionGeometry: 2 }
    }
    static func representationKind(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> RepresentationKind {
        switch tag { case 0: return .geometricShape; case 1: return .displayGeometry; case 2: return .collisionGeometry; default: throw .unknownTag(offset:offset) }
    }
    static func inertiaRequirement(_ value:InertiaRepresentationRequirement) -> UInt8 {
        switch value { case .none: 0; case .required: 1; case .exactRequired: 2 }
    }
    static func inertiaRequirement(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> InertiaRepresentationRequirement {
        switch tag { case 0: return .none; case 1: return .required; case 2: return .exactRequired; default: throw .unknownTag(offset:offset) }
    }
    static func jointKind(_ value:JointKind) -> UInt8 {
        switch value { case .fixed: 0; case .revolute: 1; case .prismatic: 2; case .spherical: 3; case .universal: 4; case .cylindrical: 5; case .planar: 6; case .screw: 7; case .sixDOF: 8; case .custom: 9 }
    }
    static func jointKind(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> JointKind {
        switch tag { case 0: return .fixed; case 1: return .revolute; case 2: return .prismatic; case 3: return .spherical; case 4: return .universal; case 5: return .cylindrical; case 6: return .planar; case 7: return .screw; case 8: return .sixDOF; case 9: return .custom; default: throw .unknownTag(offset:offset) }
    }
    static func axisKind(_ value:JointAxisKind) -> UInt8 {
        switch value { case .revolute: 0; case .prismatic: 1; case .screw: 2 }
    }
    static func axisKind(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> JointAxisKind {
        switch tag { case 0: return .revolute; case 1: return .prismatic; case 2: return .screw; default: throw .unknownTag(offset:offset) }
    }
    static func operation(_ value:FeatureOperation) -> UInt8 {
        switch value { case .descriptorValidation: 0; case .treeKinematics: 1; case .forceEvaluation: 2; case .forwardDynamics: 3; case .contactResponse: 4; case .loopAssembly: 5; case .timeIntegration: 6 }
    }
    static func operation(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> FeatureOperation {
        switch tag { case 0: return .descriptorValidation; case 1: return .treeKinematics; case 2: return .forceEvaluation; case 3: return .forwardDynamics; case 4: return .contactResponse; case 5: return .loopAssembly; case 6: return .timeIntegration; default: throw .unknownTag(offset:offset) }
    }
    static func domain(_ value:MechanicalDomain) -> UInt8 {
        switch value { case .planarTree: 0; case .spatialTree: 1; case .closedLoop: 2 }
    }
    static func domain(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> MechanicalDomain {
        switch tag { case 0: return .planarTree; case 1: return .spatialTree; case 2: return .closedLoop; default: throw .unknownTag(offset:offset) }
    }
    static func precision(_ value:NumericalPrecision) -> UInt8 {
        switch value { case .float32: 0; case .float64: 1 }
    }
    static func precision(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> NumericalPrecision {
        switch tag { case 0: return .float32; case 1: return .float64; default: throw .unknownTag(offset:offset) }
    }
    static func backend(_ value:NumericalBackend) -> UInt8 {
        switch value { case .referenceCPU: 0; case .acceleratedDevice: 1 }
    }
    static func backend(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> NumericalBackend {
        switch tag { case 0: return .referenceCPU; case 1: return .acceleratedDevice; default: throw .unknownTag(offset:offset) }
    }
    static func compilerTarget(_ value:CompilerTarget) -> UInt8 {
        switch value { case .nativeCPU: 0; case .wasiPreview1: 1; case .embeddedWasiPreview1: 2 }
    }
    static func compilerTarget(_ tag:UInt8,at offset:Int) throws(ExchangeError) -> CompilerTarget {
        switch tag { case 0: return .nativeCPU; case 1: return .wasiPreview1; case 2: return .embeddedWasiPreview1; default: throw .unknownTag(offset:offset) }
    }
}

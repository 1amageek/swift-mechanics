public struct StationaryLoadCatalog: StationaryLoadSourceBinding, Sendable {
    public let model:ModelStamp
    public let layout:ConstraintCoordinateLayout
    public let worldFrame:EntityID
    public let programs:[StationaryLoadProgram]
    public let capacity:StationaryLoadCapacity
    public let signature:[UInt8]
    public let dependencyCoordinateIDs:[UInt64]
    public init(model:CompiledMechanicalModel,layout:ConstraintCoordinateLayout,programs:[StationaryLoadProgram],capacity:StationaryLoadCapacity) throws(StationaryLoadError) {
        let n=model.tree.layout.velocityCount
        guard n > 0,n <= capacity.maximumCoordinates,layout.scales.count == n,layout.revision == model.stamp.revision,
              !programs.isEmpty,programs.count <= capacity.maximumPrograms else { throw .capacity }
        for i in 0..<n {
            guard layout.scales[i].isFinite,layout.scales[i] > 0,!layout.coordinateIDs[..<i].contains(layout.coordinateIDs[i]) else { throw .invalidCatalog }
        }
        var data=StationaryCanonicalBytes(maximum:capacity.maximumMetadataBytes)
        try data.text("stationary-load-catalog-v1");try data.text(model.stamp.identity);try data.word(model.stamp.revision);try data.text(model.tree.worldFrame.key)
        try data.word(UInt64(n));try data.scalar(layout.timeScale)
        for i in 0..<n {
            try data.word(layout.coordinateIDs[i]);try data.scalar(layout.scales[i])
            for exponent in [layout.dimensions[i].length,layout.dimensions[i].mass,layout.dimensions[i].time,layout.dimensions[i].angle,layout.dimensions[i].electricCurrent,layout.dimensions[i].temperature,layout.dimensions[i].amount,layout.dimensions[i].luminousIntensity] { try data.word(UInt64(bitPattern:Int64(exponent))) }
        }
        try data.word(UInt64(programs.count))
        for (index,p) in programs.enumerated() {
            guard p.terms.count <= capacity.maximumTermsPerProgram,!programs[..<index].contains(where:{$0.id == p.id && $0.revision == p.revision}) else { throw .invalidCatalog }
            try data.word(p.id);try data.word(p.revision);try data.word(p.gravity == nil ? 0 : 1)
            if let gravity=p.gravity {
                // FIXME(INCOMPLETE_IMPLEMENTATION): General gravity catalogs reach this constructor. Only uniform spatial and time-invariant fields have an admitted original physical sleep/wake path; distributed nonuniform or time-varying field authority and replay must be implemented before those programs may succeed.
                guard gravity.frame == model.tree.worldFrame,gravity.gradient == .zero,gravity.uniformTimeDerivative == .zero else { throw .unsupportedDomain }
                try data.text(gravity.frame.key);try data.vector(gravity.accelerationAtOrigin);try data.matrix(gravity.gradient);try data.vector(gravity.uniformTimeDerivative)
            }
            try data.word(UInt64(p.terms.count))
            for (termIndex,term) in p.terms.enumerated() {
                guard !p.terms[..<termIndex].contains(where:{$0.id == term.id}),let coordinate=layout.coordinateIDs.firstIndex(of:term.coordinateID),
                      layout.dimensions[coordinate] == (term.law.coordinateKind == .translation ? .length : .angle) else { throw .invalidCatalog }
                try data.word(term.id);try data.word(term.coordinateID);try data.word(term.law.coordinateKind == .translation ? 0 : 1)
                let law=term.law
                for value in [law.restCoordinate,law.quadraticStiffness,law.quarticStiffness,law.linearDamping,law.cubicDamping,law.maximumDisplacement,law.maximumRate] { try data.scalar(value) }
            }
        }
        self.model=model.stamp;self.layout=layout;worldFrame=model.tree.worldFrame;self.programs=programs;self.capacity=capacity;signature=data.bytes
        // Conservative whole-mechanism support retains all gravity and zero-coefficient dependencies.
        dependencyCoordinateIDs=layout.coordinateIDs
    }
    public func program(_ selection:StationaryLoadSelection) throws(StationaryLoadError) -> StationaryLoadProgram {
        guard let result=programs.first(where:{$0.id == selection.programID && $0.revision == selection.revision}) else { throw .staleBinding };return result
    }
    public func physicalSignature(model:CompiledMechanicalModel,policy:MechanismSolvePolicy,admission:DynamicsAdmission,drive:[Double],maximumBytes:Int) throws(StationaryLoadError) -> [UInt8] {
        try validate(model:model,layout:layout)
        return try StationaryMechanicalSignature.bytes(model:model,policy:policy,admission:admission,drive:drive,maximum:maximumBytes)
    }
    public func validate(model:CompiledMechanicalModel,layout:ConstraintCoordinateLayout) throws(StationaryLoadError) {
        guard model.stamp == self.model,model.tree.worldFrame == worldFrame,model.tree.layout.velocityCount == self.layout.scales.count,
              layout.coordinateIDs == self.layout.coordinateIDs,layout.scales == self.layout.scales,layout.dimensions == self.layout.dimensions,
              layout.timeScale == self.layout.timeScale,layout.revision == self.layout.revision else { throw .staleBinding }
    }
}

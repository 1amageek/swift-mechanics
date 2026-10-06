public struct ReferenceSpatialBeamEvaluator: SpatialBeamEvaluating, Sendable {
    public init() {}
    public func evaluate(_ assembly: SpatialBeamAssembly, state: SpatialBeamState,
                         admission: SpatialBeamAdmission, work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamResponse {
        let (q, v) = try SpatialBeamDomainChecking.localState(assembly, state: state, admission: admission, work: &work)
        let beam = assembly.beam, d = assembly.constitutiveDiagonal, l = assembly.frame.length
        var energy = 0.0, power = 0.0, rateForm = 0.0, kineticForm = 0.0
        var gradient = [Double](repeating: 0, count: 12)
        try SpatialBeamAlgebra.charge(80, work: &work)
        let s = beam.section, rho = beam.material.density
        let inertia = try [SpatialBeamAlgebra.positive(rho * s.area), SpatialBeamAlgebra.positive(rho * s.area),
                           SpatialBeamAlgebra.positive(rho * s.area),
                           SpatialBeamAlgebra.positive(rho * (s.secondMomentY + s.secondMomentZ)),
                           SpatialBeamAlgebra.positive(rho * s.secondMomentY), SpatialBeamAlgebra.positive(rho * s.secondMomentZ)]
        for (xi, weight) in SpatialBeamAlgebra.quadrature {
            try SpatialBeamAlgebra.cancel(admission); try SpatialBeamAlgebra.charge(2500, work: &work)
            let shape = try SpatialBeamInterpolation(xi: xi, length: l, factors: assembly.interpolationFactors)
            let dx = try SpatialBeamAlgebra.positive(l * weight)
            for row in 0..<6 {
                let strain = try SpatialBeamAlgebra.dot(shape.strain, offset: row * 12, q)
                let rate = try SpatialBeamAlgebra.dot(shape.strain, offset: row * 12, v)
                let resultant = try SpatialBeamAlgebra.finite(d[row] * strain)
                let storedEnergy = try SpatialBeamAlgebra.weightedSquare(strain, coefficient: d[row], weight: dx / 2)
                energy = try SpatialBeamAlgebra.finite(energy + storedEnergy)
                power = try SpatialBeamAlgebra.finite(power + (try SpatialBeamAlgebra.finite(rate * resultant * dx)))
                if beam.stiffnessDamping > 0 {
                    rateForm = try SpatialBeamAlgebra.finite(rateForm + SpatialBeamAlgebra.weightedSquare(rate, coefficient: d[row], weight: dx))
                }
                for i in 0..<12 {
                    gradient[i] = try SpatialBeamAlgebra.finite(gradient[i] + (try SpatialBeamAlgebra.finite(shape.strain[row * 12 + i] * resultant * dx)))
                }
                if beam.massForm == .consistent {
                    let speed = try SpatialBeamAlgebra.dot(shape.kinematics, offset: row * 12, v)
                    kineticForm = try SpatialBeamAlgebra.finite(kineticForm + SpatialBeamAlgebra.weightedSquare(speed, coefficient: inertia[row], weight: dx))
                }
            }
        }
        if beam.massForm == .endpointLumped {
            try SpatialBeamAlgebra.charge(120, work: &work)
            for node in 0..<2 { for row in 0..<6 {
                let speed = v[node * 6 + row]
                kineticForm = try SpatialBeamAlgebra.finite(kineticForm + SpatialBeamAlgebra.weightedSquare(speed, coefficient: inertia[row], weight: l / 2))
            } }
        }
        try SpatialBeamAlgebra.charge(2000, work: &work)
        let referenceGradient = try SpatialBeamAlgebra.toReference(gradient, frame: assembly.frame)
        let matrixGradient = try SpatialBeamAlgebra.action(assembly.elasticStiffness, state.displacement)
        for i in 0..<12 {
            let tolerance = i % 6 < 3 ? admission.forceTolerance : admission.momentTolerance
            try SpatialBeamAlgebra.accepts(SpatialBeamAlgebra.finite(referenceGradient[i] - matrixGradient[i]),
                scale: max(abs(referenceGradient[i]), abs(matrixGradient[i])), tolerance: tolerance, measure: "constitutiveGradient")
        }
        let matrixEnergy = try SpatialBeamAlgebra.finite(0.5 * SpatialBeamAlgebra.dot(state.displacement, matrixGradient))
        try compare(energy, matrixEnergy, tolerance: admission.energyTolerance, measure: "constitutiveEnergy")
        let nodalPower = try SpatialBeamAlgebra.dot(referenceGradient, state.velocity)
        try compare(power, nodalPower, tolerance: admission.powerTolerance, measure: "strainResultantPower")
        try balance(gradient, length: l, admission: admission)
        try SpatialBeamAlgebra.charge(3000, work: &work)
        for node in 0..<2 {
            try SpatialBeamAlgebra.cancel(admission)
            let shape = try SpatialBeamInterpolation(xi: Double(node), length: l, factors: assembly.interpolationFactors)
            let sectionLaw = try SpatialBeamSectionLaw.evaluate(assembly, shape: shape, q: q)
            let sign = node == 0 ? -1.0 : 1.0
            for axis in 0..<6 {
                let expected = sign * sectionLaw.resultant[axis], actual = gradient[node * 6 + axis]
                try compare(expected, actual, tolerance: axis < 3 ? admission.forceTolerance : admission.momentTolerance,
                            measure: "sectionBoundaryTraction")
            }
        }
        let massAction = try SpatialBeamAlgebra.action(assembly.mass, state.velocity)
        let matrixKinetic = try SpatialBeamAlgebra.finite(0.5 * SpatialBeamAlgebra.dot(state.velocity, massAction))
        let kinetic = try SpatialBeamAlgebra.finite(kineticForm / 2)
        guard kineticForm == 0 || kinetic > 0 else { throw .nonFiniteResult }
        try compare(kinetic, matrixKinetic, tolerance: admission.energyTolerance, measure: "kineticEnergy")
        let dampingAction = try SpatialBeamAlgebra.action(assembly.damping, state.velocity)
        let matrixDissipation = try SpatialBeamAlgebra.dot(state.velocity, dampingAction)
        let massDissipation = try SpatialBeamAlgebra.finite(beam.massDamping * kineticForm)
        let elasticDissipation = try SpatialBeamAlgebra.finite(beam.stiffnessDamping * rateForm)
        guard beam.massDamping == 0 || kineticForm == 0 || massDissipation > 0,
              beam.stiffnessDamping == 0 || rateForm == 0 || elasticDissipation > 0 else { throw .nonFiniteResult }
        let dissipation = try SpatialBeamAlgebra.finite(massDissipation + elasticDissipation)
        guard energy >= 0, kinetic >= 0, dissipation >= 0 else { throw .inconsistentOperator(measure: "nonnegativePhysicalForms") }
        try compare(dissipation, matrixDissipation, tolerance: admission.powerTolerance, measure: "dampingPower")
        try SpatialBeamAlgebra.cancel(admission)
        return SpatialBeamResponse(beam: beam, strainEnergy: energy, kineticEnergy: kinetic,
            elasticPower: power, dampingDissipation: dissipation, energyGradient: referenceGradient,
            elasticRestoringForce: referenceGradient.map { -$0 }, dampingForce: dampingAction.map { -$0 },
            positiveEnergyTangent: assembly.elasticStiffness)
    }

    public func field(_ assembly: SpatialBeamAssembly, state: SpatialBeamState, location: SpatialBeamLocation,
                      stress: SpatialBeamStressRequest, admission: SpatialBeamAdmission,
                      work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamField {
        // FIXME(INCOMPLETE_IMPLEMENTATION): The production field path has axial Cauchy stress only.
        // Resolved transverse/torsional stress requires physical section warping/distribution
        // input and actual law evaluation; refusing this request prevents invented stress success.
        if stress == .resolvedSection { throw .unsupportedResolvedSectionStress }
        let (q, _) = try SpatialBeamDomainChecking.localState(assembly, state: state, admission: admission, work: &work)
        let beam = assembly.beam, section = beam.section
        guard abs(location.y) <= section.outerHalfY, abs(location.z) <= section.outerHalfZ else {
            throw .invalidInput(parameter: "sectionLocationBounds")
        }
        try SpatialBeamAlgebra.charge(2500, work: &work)
        let shape = try SpatialBeamInterpolation(xi: location.xi, length: assembly.frame.length, factors: assembly.interpolationFactors)
        let sectionLaw = try SpatialBeamSectionLaw.evaluate(assembly, shape: shape, q: q)
        let strain = sectionLaw.strain, resultant = sectionLaw.resultant
        var kinematic = [Double](repeating: 0, count: 6)
        for row in 0..<6 {
            kinematic[row] = try SpatialBeamAlgebra.dot(shape.kinematics, offset: row * 12, q)
        }
        let fiberStrain = try SpatialBeamAlgebra.finite(strain[0] + location.z * strain[4] - location.y * strain[5])
        let stressValue = try SpatialBeamAlgebra.finite(beam.material.youngModulus * fiberStrain)
        let force = try SpatialBeamAlgebra.core { () throws(CoreError) in try Vector3(resultant[0], resultant[1], resultant[2]) }
        let moment = try SpatialBeamAlgebra.core { () throws(CoreError) in try Vector3(resultant[3], resultant[4], resultant[5]) }
        let localDisplacement = try SpatialBeamAlgebra.core { () throws(CoreError) in
            try Vector3(kinematic[0] + location.z * kinematic[4] - location.y * kinematic[5],
                        kinematic[1] - location.z * kinematic[3], kinematic[2] + location.y * kinematic[3])
        }
        let transform = assembly.frame.localToReference
        let displacement = try SpatialBeamAlgebra.core { () throws(CoreError) in try transform.applying(to: localDisplacement) }
        let forceReference = try SpatialBeamAlgebra.core { () throws(CoreError) in try transform.applying(to: force) }
        let momentReference = try SpatialBeamAlgebra.core { () throws(CoreError) in try transform.applying(to: moment) }
        let x = try SpatialBeamAlgebra.finite(location.xi * assembly.frame.length)
        let centerOffset = try SpatialBeamAlgebra.core { () throws(CoreError) in try transform.applying(to: Vector3(x, 0, 0)) }
        let fiberOffset = try SpatialBeamAlgebra.core { () throws(CoreError) in try transform.applying(to: Vector3(x, location.y, location.z)) }
        let center = try SpatialBeamAlgebra.core { () throws(CoreError) in try beam.first.referencePosition.adding(centerOffset) }
        let fiber = try SpatialBeamAlgebra.core { () throws(CoreError) in try beam.first.referencePosition.adding(fiberOffset) }
        try SpatialBeamAlgebra.cancel(admission)
        return SpatialBeamField(beam: beam, location: location, fiberReferencePosition: fiber,
            sectionCenterReferencePosition: center, rigidSectionFiberDisplacementInReference: displacement,
            sectionEngineeringStrain: strain, fiberAxialEngineeringStrain: fiberStrain,
            fiberAxialCauchyStress: stressValue, sectionForceInLocal: force, sectionMomentInLocal: moment,
            sectionForceInReference: forceReference, sectionMomentInReference: momentReference,
            strainEnergyPerReferenceLength: sectionLaw.energyPerLength)
    }

    private func compare(_ a: Double, _ b: Double, tolerance: NumericalTolerance,
                         measure: String) throws(SpatialBeamError) {
        try SpatialBeamAlgebra.accepts(SpatialBeamAlgebra.finite(a - b), scale: max(abs(a), abs(b)), tolerance: tolerance, measure: measure)
    }
    private func balance(_ gradient: [Double], length: Double,
                         admission: SpatialBeamAdmission) throws(SpatialBeamError) {
        for axis in 0..<3 {
            let force = try SpatialBeamAlgebra.finite(gradient[axis] + gradient[axis + 6])
            let forceScale = try SpatialBeamAlgebra.finite(abs(gradient[axis]) + abs(gradient[axis + 6]))
            try SpatialBeamAlgebra.accepts(force, scale: forceScale, tolerance: admission.forceTolerance, measure: "elasticForceBalance")
            let arm = try SpatialBeamAlgebra.finite(axis == 1 ? -length * gradient[8] : (axis == 2 ? length * gradient[7] : 0))
            let moment = try SpatialBeamAlgebra.finite(gradient[axis + 3] + gradient[axis + 9] + arm)
            let momentScale = try SpatialBeamAlgebra.finite(abs(gradient[axis + 3]) + abs(gradient[axis + 9]) + abs(arm))
            try SpatialBeamAlgebra.accepts(moment, scale: momentScale, tolerance: admission.momentTolerance, measure: "elasticMomentBalance")
        }
    }
}

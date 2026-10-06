/// Unaveraged constitutive fields, not a nodal-force stress projection.
public struct SpatialBeamField: Equatable, Sendable {
    /// Retains element, nodes, material, reference/element frame, and all source revisions.
    public let beam: SpatialBeamDefinition
    public let location: SpatialBeamLocation
    public let strainMeasure: SpatialBeamFieldMeasure
    public let curvatureMeasure: SpatialBeamFieldMeasure
    public let axialStressMeasure: SpatialBeamFieldMeasure
    public let resultantMeasure: SpatialBeamFieldMeasure
    public let displacementMeasure: SpatialBeamFieldMeasure
    public let displacementProjection: SpatialBeamFieldProjection
    public let axialStressProjection: SpatialBeamFieldProjection
    public let transverseShearResultantProjection: SpatialBeamFieldProjection
    public let fiberReferencePosition: Vector3
    public let sectionCenterReferencePosition: Vector3
    /// The reduced rigid-section beam kinematic part; excludes unresolved axial warping.
    public let rigidSectionFiberDisplacementInReference: Vector3
    /// [epsilon, gammaY, gammaZ, kappaX, kappaY, kappaZ], engineering strain / curvature [1/m].
    public let sectionEngineeringStrain: [Double]
    public let fiberAxialEngineeringStrain: Double
    /// Linear small-strain axial Cauchy stress [Pa], with no transverse/shear stress claim.
    public let fiberAxialCauchyStress: Double
    /// [N,Vy,Vz] [N] and [T,My,Mz] [Nm], acting at the section center.
    public let sectionForceInLocal: Vector3
    public let sectionMomentInLocal: Vector3
    public let sectionForceInReference: Vector3
    public let sectionMomentInReference: Vector3
    public let strainEnergyPerReferenceLength: Double
    internal init(beam: SpatialBeamDefinition, location: SpatialBeamLocation,
                  fiberReferencePosition: Vector3, sectionCenterReferencePosition: Vector3,
                  rigidSectionFiberDisplacementInReference: Vector3, sectionEngineeringStrain: [Double],
                  fiberAxialEngineeringStrain: Double, fiberAxialCauchyStress: Double,
                  sectionForceInLocal: Vector3, sectionMomentInLocal: Vector3,
                  sectionForceInReference: Vector3, sectionMomentInReference: Vector3,
                  strainEnergyPerReferenceLength: Double) {
        self.beam = beam; self.location = location; self.fiberReferencePosition = fiberReferencePosition
        strainMeasure = .infinitesimalEngineeringStrain
        curvatureMeasure = .referenceDerivativeOfInfinitesimalRotation
        axialStressMeasure = .linearAxialCauchyStress; resultantMeasure = .physicalSectionResultant
        displacementMeasure = .rigidSectionInfinitesimalDisplacement
        displacementProjection = .unaveragedRigidSectionKinematics
        axialStressProjection = .unaveragedConstitutive
        transverseShearResultantProjection = beam.formulation == .eulerBernoulli ? .equilibriumMomentGradient : .unaveragedConstitutive
        self.sectionCenterReferencePosition = sectionCenterReferencePosition
        self.rigidSectionFiberDisplacementInReference = rigidSectionFiberDisplacementInReference
        self.sectionEngineeringStrain = sectionEngineeringStrain
        self.fiberAxialEngineeringStrain = fiberAxialEngineeringStrain; self.fiberAxialCauchyStress = fiberAxialCauchyStress
        self.sectionForceInLocal = sectionForceInLocal; self.sectionMomentInLocal = sectionMomentInLocal
        self.sectionForceInReference = sectionForceInReference; self.sectionMomentInReference = sectionMomentInReference
        self.strainEnergyPerReferenceLength = strainEnergyPerReferenceLength
    }
}

import SwiftMechanics
#if canImport(AffineRigidGravityQualificationSupport)
import AffineRigidGravityQualificationSupport
#endif
import Testing

@Suite struct AffineRigidGravityQualificationTests {
    @Test func actualOffdiagonalContinuumPointIntegral() throws { try AffineRigidGravityQualificationCases.continuumPointIntegral() }
    @Test func actualProperRotationCovariance() throws { try AffineRigidGravityQualificationCases.properRotationCovariance() }
    @Test func translationRotationAndTimePotentialDerivatives() throws { try AffineRigidGravityQualificationCases.potentialFiniteDifferences() }
    @Test func actualPointPowerAndTotalPotentialRate() throws { try AffineRigidGravityQualificationCases.independentInstantaneousPower() }
    @Test func originalKernelJTAndPrescribedPower() throws { try AffineRigidGravityQualificationCases.originalKernelPrescribedPower() }
    @Test func sourceFrameAndUnsupportedTypedRefusals() throws { try AffineRigidGravityQualificationCases.sourceAndDomainRefusals() }
    @available(macOS 15.0, *)
    @Test func exactWorkCapacityAndPublicationCancellation() throws { try AffineRigidGravityQualificationCases.exactWorkCapacityCancellation() }
    @Test func originalSupplierOverflowAndPhysicalMomentRefusals() throws { try AffineRigidGravityQualificationCases.originalSupplierAndMomentRefusals() }
}

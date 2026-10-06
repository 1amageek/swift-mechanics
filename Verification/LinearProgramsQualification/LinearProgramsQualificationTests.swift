import SwiftMechanics
#if canImport(LinearProgramsQualificationSupport)
import LinearProgramsQualificationSupport
#endif
import Testing

@Suite struct LinearProgramsQualificationTests {
    @Test func boundedOriginalKKTAndPhysicalDuals() throws { try LinearProgramsQualificationCases.boundedAndPhysicalDuals() }
    @Test func unrestrictedRedundantAndFixed() throws { try LinearProgramsQualificationCases.unrestrictedAndRedundantRows() }
    @Test func originalFarkasContradiction() throws { try LinearProgramsQualificationCases.farkasOriginalContradiction() }
    @Test func trueEqualityNullRecession() throws { try LinearProgramsQualificationCases.equalityNullRecession() }
    @Test func degenerateBlandTermination() throws { try LinearProgramsQualificationCases.degenerateBlandFixture() }
    @Test func explicitFailureWorkAndProvenance() throws { try LinearProgramsQualificationCases.failureContracts() }
}

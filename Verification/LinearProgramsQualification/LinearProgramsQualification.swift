import LinearProgramsQualificationSupport

@main
struct LinearProgramsQualification {
    static func main() throws {
        try LinearProgramsQualificationCases.boundedAndPhysicalDuals(); print("LP bounded original KKT and SI duals passed")
        try LinearProgramsQualificationCases.unrestrictedAndRedundantRows(); print("LP unrestricted negative point, redundant rows and fixed bounds passed")
        try LinearProgramsQualificationCases.farkasOriginalContradiction(); print("LP original unrestricted Farkas contradiction passed")
        try LinearProgramsQualificationCases.equalityNullRecession(); print("LP equality-null and unrestricted recession passed")
        try LinearProgramsQualificationCases.degenerateBlandFixture(); print("LP independent degenerate Bland fixture passed")
        try LinearProgramsQualificationCases.failureContracts(); print("LP explicit budget, cancellation, ambiguity and provenance passed")
    }
}

import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProjectionTests {
    @Test func orthantAndConeProjectionHaveIndependentKKTGeometry() throws {
        let projector: any ConeProjecting = ReferenceConeProjector()
        var work = try ComplementarityFixtures.work()
        var orthant = [0.0, 0.0]
        try projector.project([-2, 3], cone: .nonnegativeOrthant(dimension: 2), into: &orthant, work: &work)
        #expect(orthant == [0, 3])
        let cone = ConeLayout.associatedFrictionCones(coefficients: [0.5])
        var output = [Double](repeating: 0, count: 3)
        try projector.project([0, 1, 0], cone: cone, into: &output, work: &work)
        #expect(ComplementarityFixtures.close(output[0], 0.4, absolute: 1e-12, relative: 1e-11))
        #expect(ComplementarityFixtures.close(output[1], 0.2, absolute: 1e-12, relative: 1e-11))
        #expect(output[2] == 0)
        // Output is on the boundary; input-output is a polar normal.
        #expect(abs(output[1] - 0.5 * output[0]) < 1e-12)
        #expect(abs(output[0] * -0.4 + output[1] * 0.8) < 1e-12)
        #expect(try projector.violation(output, cone: cone, dual: false, work: &work) < 1e-12)
        try projector.project([2, 0.3, 0.4], cone: cone, into: &output, work: &work)
        #expect(output == [2, 0.3, 0.4])
        try projector.project([-1, 0.1, 0], cone: cone, into: &output, work: &work)
        #expect(output == [0, 0, 0])
        #expect(ComplementarityFixtures.close(try projector.violation([0.3, 1, 0], cone: cone, dual: true, work: &work), 0.2, absolute: 1e-12))
        #expect(try projector.violation([0.5, -1, 0], cone: cone, dual: true, work: &work) == 0)
        try projector.project([1, 7, -9], cone: .associatedFrictionCones(coefficients: [0]), into: &output, work: &work)
        #expect(output == [1, 0, 0])
        #expect(try projector.violation([0, -7, 9], cone: .associatedFrictionCones(coefficients: [0]), dual: true, work: &work) == 0)
    }

    @Test func productBlocksAndFailureDomains() throws {
        let projector: any ConeProjecting = ReferenceConeProjector()
        let cone = ConeLayout.associatedFrictionCones(coefficients: [0.5, 1, 0])
        var work = try ComplementarityFixtures.work()
        var output = [Double](repeating: 0, count: 9)
        try projector.project([0, 1, 0, -3, 1, 0, 2, 3, 4], cone: cone, into: &output, work: &work)
        #expect(ComplementarityFixtures.close(output[0], 0.4, absolute: 1e-12))
        #expect(ComplementarityFixtures.close(output[1], 0.2, absolute: 1e-12))
        #expect(Array(output[3..<6]) == [0, 0, 0])
        #expect(Array(output[6..<9]) == [2, 0, 0])
        #expect(throws: ComplementarityError.invalidCone(block: 0)) {
            try ConeLayout.associatedFrictionCones(coefficients: [-0.1]).validatedDimension()
        }
        #expect(throws: ComplementarityError.invalidCone(block: 0)) {
            try ConeLayout.associatedFrictionCones(coefficients: [.greatestFiniteMagnitude]).validatedDimension()
        }
        var short = [0.0]
        #expect(throws: ComplementarityError.numerical(.invalidDimensions)) {
            try projector.project([0, 1, 0], cone: .associatedFrictionCones(coefficients: [1]), into: &short, work: &work)
        }
        var triple = [0.0, 0.0, 0.0]
        #expect(throws: ComplementarityError.numerical(.nonFiniteInput)) {
            try projector.project([.nan, 1, 0], cone: .associatedFrictionCones(coefficients: [1]), into: &triple, work: &work)
        }
        #expect(throws: ComplementarityError.numerical(.nonFiniteResult)) {
            try projector.project([0, .greatestFiniteMagnitude, .greatestFiniteMagnitude], cone: .associatedFrictionCones(coefficients: [1]), into: &triple, work: &work)
        }
        var limited = NumericalWork(budget: try NumericalBudget(scalarStorage: 7, arithmeticOperations: 0, iterations: 0))
        #expect(throws: ComplementarityError.numerical(.resourceLimit(resource: .arithmeticOperations, limit: 0))) {
            try projector.project([0, 1, 0], cone: .associatedFrictionCones(coefficients: [1]), into: &triple, work: &limited)
        }
    }
}

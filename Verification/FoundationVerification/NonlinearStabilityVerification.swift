import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyNonlinearStability() throws {
        let context = try NonlinearStabilityProbeContext()
        try verifySymmetricStability(context)
        try verifySecondaryStability(context, sign: 1)
        try verifySecondaryStability(context, sign: -1)
        try verifyStabilityOwnerRefusal(context)
    }

    private static func stabilityPosition(_ context: NonlinearStabilityProbeContext,
        u: Double, v: Double) -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        values[context.firstIndex] = u + v
        values[context.secondIndex] = u - v
        values[context.thirdIndex] = 2 * u
        return values
    }

    private static func stabilityDirection(_ context: NonlinearStabilityProbeContext,
        sign: Double) -> [Double] {
        var values = [Double](repeating: sign, count: 4)
        values[context.thirdIndex] = 2 * sign
        return values
    }

    @inline(never) private static func verifyOriginalStabilityPoint(_ context: NonlinearStabilityProbeContext,
        point: NonlinearStabilityPoint) throws {
        let q1 = point.position[context.firstIndex], q2 = point.position[context.secondIndex]
        let q3 = point.position[context.thirdIndex], p = point.parameter
        try require(abs(q3 - q1 - q2) < 1e-8)
        let potential = -0.5 * (q1*q1 + q2*q2) + 0.25 * (q1*q1*q1*q1 + q2*q2*q2*q2)
            + 0.5 * q3*q3 - p * (q1 + q2)
        try require(abs(point.energy - potential) < 1e-7)
        var gradient = [Double](repeating: 0, count: 3)
        gradient[context.firstIndex] = -q1 + q1*q1*q1 - p
        gradient[context.secondIndex] = -q2 + q2*q2*q2 - p
        gradient[context.thirdIndex] = q3
        var reaction = [Double](repeating: -q3, count: 3)
        reaction[context.thirdIndex] = q3
        for i in 0..<3 {
            try require(abs(point.physicalGradient[i] - gradient[i]) < 1e-7)
            try require(abs(point.generalizedReaction[i] - reaction[i]) < 1e-7)
            try require(abs(gradient[i] - reaction[i]) < 1e-7)
        }
        try require(point.rowMultipliers.count == 1 && abs(point.rowMultipliers[0] + q3) < 1e-7)
        try require(point.stiffnessEigenvalues.count == 2 && point.modes.count == 6)
        var stiffness = [Double](repeating: 0, count: 3)
        stiffness[context.firstIndex] = -1 + 3*q1*q1
        stiffness[context.secondIndex] = -1 + 3*q2*q2
        stiffness[context.thirdIndex] = 1
        for mode in 0..<2 {
            let lambda = point.stiffnessEigenvalues[mode]
            var norm = 0.0
            for i in 0..<3 { norm += point.modes[mode*3+i] * point.modes[mode*3+i] }
            try require(abs(norm - 1) < 1e-7)
            try require(abs(point.modes[mode*3+context.thirdIndex]
                - point.modes[mode*3+context.firstIndex] - point.modes[mode*3+context.secondIndex]) < 1e-7)
            for column in 0..<2 {
                var residual = 0.0
                for i in 0..<3 {
                    residual += context.source.nullBasis[i*2+column] * (stiffness[i] - lambda)
                        * point.modes[mode*3+i]
                }
                try require(abs(residual) < 1e-7)
            }
        }
    }

    @inline(never) private static func verifySymmetricStability(_ context: NonlinearStabilityProbeContext) throws {
        let service: any NonlinearStabilityContinuing = ReferenceNonlinearStabilityContinuation()
        var work = context.work()
        var state = try context.start(using: service, position: stabilityPosition(context, u: 0.8, v: 0),
            parameter: 1.312, initialDirection: stabilityDirection(context, sign: -1), work: &work)
        let initial = state
        try verifyOriginalStabilityPoint(context, point: state.point)
        try require(state.point.stiffnessEigenvalues[0] > 0)
        for _ in 0..<20 {
            let prior = state
            state = try context.advance(using: service, state: prior, arcStep: 0.15, work: &work)
            try verifyOriginalStabilityPoint(context, point: state.point)
            let u = state.point.position[context.firstIndex]
            try require(abs(state.point.position[context.secondIndex] - u) < 1e-7)
            try require(abs(state.point.parameter - u - u*u*u) < 1e-7)
            if prior.point.stiffnessEigenvalues[0] > 0 && state.point.stiffnessEigenvalues[0] < 0 {
                try require(prior.acceptedPoints > initial.acceptedPoints)
                var refusedNonadjacent = false
                do throws(NonlinearStabilityFailure) {
                    _ = try context.critical(using: service, left: initial, right: state, work: &work)
                } catch {
                    guard case .noCriticalBracket = error.cause else { throw FoundationVerificationError.unexpectedFailure }
                    try require(error.priorAcceptedState === state)
                    refusedNonadjacent = true
                }
                try require(refusedNonadjacent)
                let critical = try context.critical(using: service, left: prior, right: state, work: &work)
                guard case .bifurcationCandidate = critical.kind else { throw FoundationVerificationError.analyticCheckFailed }
                try verifyOriginalStabilityPoint(context, point: critical.point)
                let expected = 1 / Double(3).squareRoot()
                try require(abs(critical.point.position[context.firstIndex] - expected) < 1e-6)
                try require(abs(critical.point.parameter - 4 / (3 * Double(3).squareRoot())) < 1e-6)
                try require(critical.bracketWidth <= context.policy.criticalWidth)
                return
            }
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @inline(never) private static func verifySecondaryStability(_ context: NonlinearStabilityProbeContext,
        sign: Double) throws {
        let service: any NonlinearStabilityContinuing = ReferenceNonlinearStabilityContinuation()
        var work = context.work()
        var state = try context.start(using: service,
            position: stabilityPosition(context, u: 0.2, v: sign * Double(0.88).squareRoot()),
            parameter: 0.736, initialDirection: stabilityDirection(context, sign: 1), work: &work)
        var maximumLoad = state.point.parameter
        var foundCritical = false
        for _ in 0..<40 {
            let prior = state
            state = try context.advance(using: service, state: prior, arcStep: 0.12, work: &work)
            try verifyOriginalStabilityPoint(context, point: state.point)
            let u = (state.point.position[context.firstIndex] + state.point.position[context.secondIndex]) / 2
            let v = (state.point.position[context.firstIndex] - state.point.position[context.secondIndex]) / 2
            try require(sign * v > 0 && abs(v*v + 3*u*u - 1) < 1e-7)
            try require(abs(state.point.parameter - 4*u + 8*u*u*u) < 1e-7)
            maximumLoad = max(maximumLoad, state.point.parameter)
            if !foundCritical && prior.point.stiffnessEigenvalues[0] > 0 && state.point.stiffnessEigenvalues[0] < 0 {
                let critical = try context.critical(using: service, left: prior, right: state, work: &work)
                guard case .limitPointCandidate = critical.kind else { throw FoundationVerificationError.analyticCheckFailed }
                try verifyOriginalStabilityPoint(context, point: critical.point)
                let q = critical.point.position
                try require(abs((q[context.firstIndex] + q[context.secondIndex])/2 - 1/Double(6).squareRoot()) < 1e-6)
                try require(abs(critical.point.parameter - 8/(3*Double(6).squareRoot())) < 1e-6)
                foundCritical = true
            }
            if u >= 0.5 {
                try require(foundCritical && maximumLoad > 1.07 && state.point.parameter < maximumLoad - 0.03)
                return
            }
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @inline(never) private static func verifyStabilityOwnerRefusal(_ context: NonlinearStabilityProbeContext) throws {
        let service: any NonlinearStabilityContinuing = ReferenceNonlinearStabilityContinuation()
        var work = context.work()
        let state = try context.start(using: service, position: stabilityPosition(context, u: 0.8, v: 0),
            parameter: 1.312, initialDirection: stabilityDirection(context, sign: 1), work: &work)
        let fresh = try NonlinearStabilityProbeContext()
        var refused = false
        do throws(NonlinearStabilityFailure) {
            _ = try fresh.advance(using: service, state: state, arcStep: 0.12, work: &work)
        } catch {
            guard case .staleSource = error.cause else { throw FoundationVerificationError.unexpectedFailure }
            try require(error.priorAcceptedState === state)
            refused = true
        }
        try require(refused && state.acceptedPoints == 1)
    }
}

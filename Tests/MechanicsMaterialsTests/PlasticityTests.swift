import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PlasticityTests {
    @Test func analyticRadialReturnRecoveryAndDiscreteDissipation() throws {
        let material: any PlasticResponding = try MaterialsFixtures.plasticity()
        let initial = material.initialHistory()
        let e = try SymmetricTensor(xx: 0.04, yy: -0.02, zz: -0.02)
        let trial = try material.evaluate(greenStrain: e, acceptedHistory: initial)
        let gamma = (48.0 - 20) / 1300
        let returnedQ = 20 + 100 * gamma
        #expect(trial.isPlastic)
        #expect(MaterialsFixtures.close(trial.plasticMultiplierIncrement, gamma))
        #expect(MaterialsFixtures.close(trial.history.accumulatedPlasticStrain, gamma))
        #expect(MaterialsFixtures.close(trial.history.plasticGreenStrain.xx, gamma))
        #expect(MaterialsFixtures.close(trial.secondPiolaStress.xx, 2 * returnedQ / 3))
        #expect(MaterialsFixtures.close(trial.secondPiolaStress.yy, -returnedQ / 3))
        #expect(MaterialsFixtures.close(trial.dissipationIncrement, 20 * gamma + 50 * gamma * gamma))
        let work = try trial.secondPiolaStress.contracted(with: trial.history.plasticGreenStrain)
        #expect(MaterialsFixtures.close(work - 50 * gamma * gamma, trial.dissipationIncrement))
        let elastic = try e.subtracting(trial.history.plasticGreenStrain)
        let expectedEnergy = try 400 * elastic.contracted(with: elastic) + 50 * gamma * gamma
        #expect(MaterialsFixtures.close(trial.energyDensity, expectedEnergy))
        let recovered = try material.evaluate(greenStrain: trial.history.plasticGreenStrain, acceptedHistory: trial.history)
        #expect(!recovered.isPlastic)
        #expect(try recovered.secondPiolaStress.norm() < 1e-9)
        #expect(recovered.history == trial.history)
        #expect(recovered.dissipationIncrement == 0)
        #expect(initial.plasticGreenStrain == .zero)
        #expect(initial.accumulatedPlasticStrain == 0)
    }

    @Test func shearCycleAndIndependentRejectedHistories() throws {
        let material = try MaterialsFixtures.plasticity()
        let initial = material.initialHistory()
        let shear = try SymmetricTensor(xx: 0, yy: 0, zz: 0, xy: 0.03)
        let first = try material.evaluate(greenStrain: shear, acceptedHistory: initial)
        let firstHistory = first.history
        let gamma = (3.0.squareRoot() * 800 * 0.03 - 20) / 1300
        #expect(MaterialsFixtures.close(first.plasticMultiplierIncrement, gamma))
        #expect(MaterialsFixtures.close(first.history.plasticGreenStrain.xy, 3.0.squareRoot() * gamma / 2))
        let rejectedAlternative = try material.evaluate(greenStrain: shear.scaled(by: -1), acceptedHistory: initial)
        #expect(MaterialsFixtures.close(rejectedAlternative.history.plasticGreenStrain.xy, -first.history.plasticGreenStrain.xy))
        #expect(initial == material.initialHistory())
        var accepted = first.history
        var dissipation = first.dissipationIncrement
        for scalar in [0.01, -0.03, -0.01, 0.03, 0.0] {
            let e = try SymmetricTensor(xx: 0, yy: 0, zz: 0, xy: scalar)
            let next = try material.evaluate(greenStrain: e, acceptedHistory: accepted)
            let plasticIncrement = try next.history.plasticGreenStrain.subtracting(accepted.plasticGreenStrain)
            let hardeningIncrement = 50 * (next.history.accumulatedPlasticStrain * next.history.accumulatedPlasticStrain - accepted.accumulatedPlasticStrain * accepted.accumulatedPlasticStrain)
            #expect(MaterialsFixtures.close(try next.secondPiolaStress.contracted(with: plasticIncrement) - hardeningIncrement, next.dissipationIncrement))
            #expect(next.dissipationIncrement >= 0)
            #expect(next.history.accumulatedPlasticStrain >= accepted.accumulatedPlasticStrain)
            #expect(abs(try next.history.plasticGreenStrain.trace()) < 1e-12)
            accepted = next.history
            dissipation += next.dissipationIncrement
        }
        #expect(dissipation > first.dissipationIncrement)
        #expect(first.history == firstHistory)
    }

    @Test func consistentPlasticAndElasticBranchTangents() throws {
        let material: any PlasticResponding = try MaterialsFixtures.plasticity()
        let initial = material.initialHistory()
        let loaded = try material.evaluate(greenStrain: SymmetricTensor(xx: 0.04, yy: -0.02, zz: -0.02), acceptedHistory: initial).history
        let direction = try SymmetricTensor(xx: 0.1, yy: -0.04, zz: 0.03, xy: 0.06, yz: -0.02, xz: 0.05)
        for history in [initial, loaded] {
            for scale in [0.001, 0.07] {
                let e = try SymmetricTensor(xx: scale, yy: -scale / 2, zz: -scale / 2, xy: scale / 4)
                let derivative = try material.tangent(greenStrain: e, direction: direction, acceptedHistory: history)
                let step = 1e-6
                let plus = try material.evaluate(greenStrain: e.adding(direction.scaled(by: step)), acceptedHistory: history)
                let minus = try material.evaluate(greenStrain: e.subtracting(direction.scaled(by: step)), acceptedHistory: history)
                let finiteDifference = try plus.secondPiolaStress.subtracting(minus.secondPiolaStress).scaled(by: 0.5 / step)
                #expect(try MaterialsFixtures.tensorClose(derivative, finiteDifference, absolute: 1e-3, relative: 1e-6))
            }
        }
    }

    @Test func finiteRotationAndFirstPiolaTangentPreserveHistory() throws {
        let material: any PlasticResponding = try MaterialsFixtures.plasticity()
        let history = material.initialHistory()
        let f = try Matrix3(1.05, 0.04, 0.01, 0, 0.98, 0.01, 0, 0, 0.99)
        let h = try Matrix3(0.1, -0.05, 0.03, 0.04, -0.03, -0.02, 0.01, 0.05, 0.04)
        let base = try material.evaluate(deformationGradient: f, acceptedHistory: history)
        #expect(base.constitutive.isPlastic)
        let q = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 2).matrix()
        let rotated = try material.evaluate(deformationGradient: q.multiplied(by: f), acceptedHistory: history)
        #expect(try MaterialsFixtures.tensorClose(rotated.constitutive.history.plasticGreenStrain, base.constitutive.history.plasticGreenStrain, absolute: 1e-12))
        #expect(MaterialsFixtures.close(rotated.constitutive.history.accumulatedPlasticStrain, base.constitutive.history.accumulatedPlasticStrain, absolute: 1e-12))
        #expect(try MaterialsFixtures.matrixClose(rotated.response.firstPiolaStress, q.multiplied(by: base.response.firstPiolaStress)))
        #expect(try MaterialsFixtures.matrixClose(rotated.response.cauchyStress, q.multiplied(by: base.response.cauchyStress).multiplied(by: q.transposed())))
        #expect(MaterialsFixtures.close(rotated.constitutive.dissipationIncrement, base.constitutive.dissipationIncrement))
        let pureRotation = try material.evaluate(deformationGradient: q, acceptedHistory: history)
        #expect(!pureRotation.constitutive.isPlastic)
        #expect(try pureRotation.response.secondPiolaStress.norm() < 1e-9)
        let step = 1e-6
        let plus = try material.evaluate(deformationGradient: f.adding(h.scaled(by: step)), acceptedHistory: history)
        let minus = try material.evaluate(deformationGradient: f.subtracting(h.scaled(by: step)), acceptedHistory: history)
        let derivative = try material.tangent(deformationGradient: f, direction: h, acceptedHistory: history)
        #expect(try MaterialsFixtures.matrixClose(derivative.firstPiolaDirection, plus.response.firstPiolaStress.subtracting(minus.response.firstPiolaStress).scaled(by: 0.5 / step)))
        #expect(try MaterialsFixtures.matrixClose(derivative.cauchyDirection, plus.response.cauchyStress.subtracting(minus.response.cauchyStress).scaled(by: 0.5 / step)))
        let transformed = try material.tangent(deformationGradient: q.multiplied(by: f), direction: q.multiplied(by: h), acceptedHistory: history)
        #expect(try MaterialsFixtures.matrixClose(transformed.firstPiolaDirection, q.multiplied(by: derivative.firstPiolaDirection)))
        #expect(history.accumulatedPlasticStrain == 0)
    }

    @Test func boundsMismatchOverflowAndAcceptanceFailureAreExplicit() throws {
        let material = try MaterialsFixtures.plasticity()
        let history = material.initialHistory()
        let other = try MaterialsFixtures.plasticity(maximumAlpha: 0.001)
        let e = try SymmetricTensor(xx: 0.04, yy: -0.02, zz: -0.02)
        #expect(throws: MaterialError.incompatibleHistory) { try other.evaluate(greenStrain: e, acceptedHistory: history) }
        #expect(throws: MaterialError.self) { try other.evaluate(greenStrain: e, acceptedHistory: other.initialHistory()) }
        #expect(throws: MaterialError.self) { try material.evaluate(greenStrain: SymmetricTensor(xx: 1, yy: 0, zz: 0), acceptedHistory: history) }
        #expect(throws: MaterialError.invalidParameter(name: "yieldResidualTolerance")) { try MaterialsFixtures.plasticity(absoluteTolerance: 0) }
        #expect(throws: MaterialError.nonFiniteResult(operation: "returnModulus")) {
            try J2Plasticity(elasticity: IsotropicElasticity(bulkModulus: 1e307, shearModulus: 1e307), initialYieldStress: 20, hardeningModulus: .greatestFiniteMagnitude,
                             maximumAccumulatedPlasticStrain: 1, domain: MaterialsFixtures.domain(),
                             residualAbsoluteTolerance: 1e-9, residualRelativeTolerance: 1e-10)
        }
        let strict = try MaterialsFixtures.plasticity(absoluteTolerance: .leastNonzeroMagnitude, relativeTolerance: 0)
        let nontrivial = try SymmetricTensor(xx: 0.031, yy: -0.013, zz: -0.018, xy: 0.007, yz: 0.004, xz: 0.011)
        do {
            _ = try strict.evaluate(greenStrain: nontrivial, acceptedHistory: strict.initialHistory())
            Issue.record("Strict yield residual must reject this roundoff-limited return")
        } catch {
            guard case MaterialError.nonConvergence(let residual, let tolerance) = error else {
                Issue.record("Expected typed numerical acceptance failure, received \(error)")
                return
            }
            #expect(residual > tolerance)
        }
        #expect(history == material.initialHistory())
    }
}

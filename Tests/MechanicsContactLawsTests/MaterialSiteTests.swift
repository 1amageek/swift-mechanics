import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct MaterialSiteTests {
    private func identity(firstKey: String = "vertex-4", secondKey: String = "face-12",
                          siteRevision: UInt64 = 1) throws -> ContactIdentity {
        let body = try ContactFixtures.reference("deforming-body", kind: .body)
        return try ContactIdentity(key: "self-contact", firstBody: body, secondBody: body,
            frame: ContactFixtures.reference("world", kind: .frame), firstGeometryRevision: 1,
            secondGeometryRevision: 1, tangentLayoutRevision: 1,
            firstMaterialSite: ContactMaterialSite(key: firstKey, revision: siteRevision),
            secondMaterialSite: ContactMaterialSite(key: secondKey, revision: 1))
    }

    @Test func physicalIdentityRequiresTwoDistinctMaterialSites() throws {
        let body = try ContactFixtures.reference("body", kind: .body)
        let frame = try ContactFixtures.reference("world", kind: .frame)
        let site = try ContactMaterialSite(key: "same-feature", revision: 1)
        #expect(throws: ContactLawError.invalidIdentity) { try ContactMaterialSite(key: "", revision: 1) }
        #expect(throws: ContactLawError.invalidIdentity) {
            try ContactIdentity(key: "self", firstBody: body, secondBody: body, frame: frame,
                firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1)
        }
        #expect(throws: ContactLawError.invalidIdentity) {
            try ContactIdentity(key: "self", firstBody: body, secondBody: body, frame: frame,
                firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1,
                firstMaterialSite: site)
        }
        #expect(throws: ContactLawError.invalidIdentity) {
            try ContactIdentity(key: "self", firstBody: body, secondBody: body, frame: frame,
                firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1,
                firstMaterialSite: site, secondMaterialSite: ContactMaterialSite(key: site.key, revision: 2))
        }
        #expect(throws: ContactLawError.invalidIdentity) {
            try ContactIdentity(key: "self", firstBody: body,
                secondBody: ModelReference(id: body.id, revision: 2), frame: frame,
                firstGeometryRevision: 1, secondGeometryRevision: 1, tangentLayoutRevision: 1,
                firstMaterialSite: site, secondMaterialSite: ContactMaterialSite(key: "different", revision: 1))
        }
        let actual = try identity()
        #expect(actual.firstBody == actual.secondBody)
        #expect(actual.firstMaterialSite?.key == "vertex-4" && actual.secondMaterialSite?.key == "face-12")
    }

    @Test func sameBodyFrictionHasActualForceEnergyAndReplay() throws {
        let id = try identity(), pair = try ContactFixtures.pair(friction: ContactFixtures.friction())
        let accepted = try ContactFixtures.history(pair, identity: id)
        let input = try ContactFixtures.input(identity: id, velocity: Vector3(1, 0, 0))
        let response = try ContactFixtures.evaluate(input, pair: pair, accepted: accepted)
        #expect(ContactFixtures.close(response.compressiveNormalForce, 10))
        #expect(ContactFixtures.close(response.tangentialForceFirst, -1))
        #expect(ContactFixtures.close(response.normalStoredEnergy, 0.05))
        #expect(ContactFixtures.close(response.tangentialStoredEnergy, 0.0005))
        #expect(ContactFixtures.close(response.tangentialDissipationEnergy, 0.0005))
        #expect(ContactFixtures.close(response.relativeMechanicalPower, -1))
        #expect(response.frictionRegime == .sticking)
        #expect(response.trialHistory.identity == id && response.trialHistory.sequence == 1)
        let reconstructed = try identity()
        #expect(reconstructed == id)
        let replay = try ContactFixtures.evaluate(ContactFixtures.input(identity: reconstructed, velocity: Vector3(1, 0, 0)), pair: pair, accepted: accepted)
        #expect(replay.trialHistory == response.trialHistory && replay.forceOnB == response.forceOnB)
        #expect(accepted.sequence == 0 && accepted.firstBristleDisplacement == 0)
    }

    @Test func orderedSitesAndTopologyRevisionCannotReuseHistory() throws {
        let id = try identity(), pair = try ContactFixtures.pair(friction: ContactFixtures.friction())
        let accepted = try ContactFixtures.history(pair, identity: id)
        for changed in try [identity(firstKey: "face-12", secondKey: "vertex-4"), identity(siteRevision: 2)] {
            #expect(throws: ContactLawError.staleHistory) {
                try ContactFixtures.evaluate(ContactFixtures.input(identity: changed), pair: pair, accepted: accepted)
            }
        }
        #expect(accepted.identity == id && accepted.sequence == 0)
    }

    @Test func materialSiteMetadataAndStorageAreBounded() throws {
        let pair = try ContactFixtures.pair(), evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        let long = try identity(firstKey: String(repeating: "x", count: 3000))
        let history = try ContactFixtures.history(pair, identity: long)
        let input = try ContactFixtures.input(identity: long)
        var bounded = try ContactFixtures.work(operations: 5000)
        #expect(throws: ContactLawError.resourceLimit(resource: .operations, limit: 5000)) {
            try evaluator.evaluate(input: input, pair: pair, accepted: history, policy: ContactFixtures.policy(), work: &bounded)
        }
        let short = try identity(), shortHistory = try ContactFixtures.history(pair, identity: short)
        var storage = try ContactFixtures.work(storage: 319)
        #expect(throws: ContactLawError.resourceLimit(resource: .scalarStorage, limit: 319)) {
            try evaluator.evaluate(input: ContactFixtures.input(identity: short), pair: pair,
                accepted: shortHistory, policy: ContactFixtures.policy(), work: &storage)
        }
        var exact = try ContactFixtures.work(storage: 320)
        _ = try evaluator.evaluate(input: ContactFixtures.input(identity: short), pair: pair,
            accepted: shortHistory, policy: ContactFixtures.policy(), work: &exact)
        #expect(exact.peakScalarStorage == 320)
        #expect(shortHistory.sequence == 0 && history.sequence == 0)
    }

    @Test func legacyDistinctBodyBudgetRemainsUnchanged() throws {
        let pair = try ContactFixtures.pair(), id = try ContactFixtures.identity()
        let accepted = try ContactFixtures.history(pair, identity: id)
        let evaluator: any ContactLawEvaluating = CompliantContactEvaluator()
        var work = try ContactFixtures.work(storage: 256)
        let result = try evaluator.evaluate(input: ContactFixtures.input(identity: id), pair: pair,
            accepted: accepted, policy: ContactFixtures.policy(), work: &work)
        #expect(work.peakScalarStorage == 256 && result.trialHistory.sequence == 1)
        #expect(id.firstMaterialSite == nil && id.secondMaterialSite == nil)
    }
}

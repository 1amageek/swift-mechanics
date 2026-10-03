import Testing
import MechanicsCore
import MechanicsModel
import MechanicsRuntime
import MechanicsIntegration
import MechanicsCollision
import MechanicsHybrid

@Suite("Hybrid bounded continuation authority")
struct HybridContinuationTests {
    @Test func exactSerializedCapacityBoundaryAndLongScaleCount() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let model=try HybridFixtures.model(), impact=try HybridFixtures.impactPolicy()
        func policy(_ bytes: Int) throws -> HybridEvolutionPolicy {
            try HybridEvolutionPolicy(maximumEvents:2,maximumQueries:10,maximumRootIterations:10,maximumCatalogEvents:2,
                maximumContinuationBytes:bytes,timeTolerance:1e-9,minimumEventSpacing:1e-6)
        }
        // 176 fixed signature/record bytes + model UTF8 + 8 provider bytes + five event/q/v/scale words.
        let required=176+model.stamp.identity.utf8.count+8+40
        let exact=try policy(required)
        let catalog=try HybridEventCatalog(model:model.stamp,geometryRevision:1,eventIDs:[10],providerSignature:[UInt8](repeating:7,count:8),policy:exact)
        let provider=try HybridContinuationProvider(catalog:catalog,policy:exact,impactPolicy:impact,model:model)
        #expect(provider.schema.maximumBytes == required)
        let initial=try provider.initialRecord(physical:model.descriptor.initialState)
        let history=try provider.history(initial)
        let full=try provider.record(physical:model.descriptor.initialState,previous:history,eventIDs:[10])
        #expect(full.bytes.count == required)
        let short=try policy(required-1)
        do { _=try HybridContinuationProvider(catalog:catalog,policy:short,impactPolicy:impact,model:model); Issue.record("Expected exact preflight capacity failure.") }
        catch { #expect(error.code == .capacityExceeded) }
        let manyScales=try HybridPolicy(maximumContacts:2,maximumColliders:2,maximumBodies:2,maximumVelocities:512,maximumIdentifierBytes:256,
            lengthTolerance:1e-7,normalTolerance:1e-10,speedTolerance:1e-8,independenceTolerance:1e-10,
            impulseScales:[Double](repeating:1,count:512),momentumAbsolute:1e-9,momentumRelative:1e-10,energyAbsolute:1e-8,energyRelative:1e-10)
        let limited=try policy(256)
        do { _=try HybridContinuationProvider(catalog:catalog,policy:limited,impactPolicy:manyScales,model:model); Issue.record("Expected scale preflight failure before signature creation.") }
        catch { #expect(error.code == .capacityExceeded) }
    }
    @Test func foreignPreviousHistoryFailsAtRecordGeneration() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let model=try HybridFixtures.model(), policy=try HybridFixtures.evolutionPolicy(), impact=try HybridFixtures.impactPolicy()
        func provider(id: UInt64, signature: UInt8, revision: UInt64) throws -> HybridContinuationProvider {
            try HybridContinuationProvider(catalog:HybridEventCatalog(model:model.stamp,geometryRevision:revision,eventIDs:[id],providerSignature:[signature],policy:policy),
                policy:policy,impactPolicy:impact,model:model)
        }
        let target=try provider(id:10,signature:1,revision:1)
        let initial=try target.initialRecord(physical:model.descriptor.initialState), source=try target.history(initial)
        let accepted=try target.record(physical:model.descriptor.initialState,previous:source,eventIDs:[10])
        let good=try target.history(accepted)
        #expect(try target.history(target.record(physical:model.descriptor.initialState,previous:good,eventIDs:[])).lastEventIDs == [10])
        for foreign in [try provider(id:20,signature:1,revision:1),try provider(id:10,signature:2,revision:1),try provider(id:10,signature:1,revision:2)] {
            let seed=try foreign.history(foreign.initialRecord(physical:model.descriptor.initialState))
            let foreignHistory=try foreign.history(foreign.record(physical:model.descriptor.initialState,previous:seed,eventIDs:foreign.catalog.eventIDs))
            do { _=try target.record(physical:model.descriptor.initialState,previous:foreignHistory,eventIDs:[]); Issue.record("Expected foreign history generation failure.") }
            catch { #expect(error.code == .incompatibleContinuation) }
        }
        do { _=try target.record(physical:model.descriptor.initialState,previous:good,eventIDs:[20]); Issue.record("Expected unknown new event ID failure.") }
        catch { #expect(error.code == .invalidContributor) }
    }
    @Test func boundedEnvironmentMetadataFailsBeforeSignatureMaterialization() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let model=try HybridFixtures.model(q:1.5,v:0), token=HybridCancellation()
        let equation=try PrismaticBallisticEquation(model:model,accelerationMetersPerSecondSquared:-10,cancellation:token,maximumIdentityBytes:256)
        let impact=try HybridFixtures.impactPolicy(), sphere=try HybridFixtures.proxy("sphere",body:"ball0",shape:.sphere(radius:0.5),pose:model.initialSnapshot.bodies[1].motion.pose)
        let plane=try HybridFixtures.proxy("floor",body:"ground",shape:.halfSpace,pose:.identity)
        let small=try HybridEvolutionPolicy(maximumEvents:2,maximumQueries:10,maximumRootIterations:10,maximumCatalogEvents:2,
            maximumContinuationBytes:512,timeTolerance:1e-9,minimumEventSpacing:1e-6)
        do { _=try SpherePlaneBallisticEnvironment(model:model,equation:equation,sphere:sphere,plane:plane,sphereToBody:.identity,planeToBody:.identity,
            law:HybridFixtures.pair(),eventID:10,geometryRevision:1,queryPolicy:HybridFixtures.queryPolicy(),evolutionPolicy:small,impactPolicy:impact)
            Issue.record("Expected fixed and text preflight failure.")
        } catch HybridError.runtime(let cause) { #expect(cause.code == .capacityExceeded) } catch { throw error }
        let representation=try BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:String(repeating:"large-",count:1024),
            provenance:SourceProvenance(source:"bounded-test",revision:1),quality:.exact))
        let long=try CollisionProxy(colliderID:sphere.geometry.colliderID,bodyID:sphere.geometry.bodyID,frameID:sphere.geometry.frameID,
            geometryRevision:1,frameRevision:1,shape:sphere.geometry.shape,margin:0,representations:representation,expectedSourceRevision:1,
            resolution:.analytic,pose:sphere.pose,filter:sphere.filter)
        do { _=try SpherePlaneBallisticEnvironment(model:model,equation:equation,sphere:long,plane:plane,sphereToBody:.identity,planeToBody:.identity,
            law:HybridFixtures.pair(),eventID:10,geometryRevision:1,queryPolicy:HybridFixtures.queryPolicy(),evolutionPolicy:HybridFixtures.evolutionPolicy(),impactPolicy:impact)
            Issue.record("Expected bounded identifier traversal failure.")
        } catch HybridError.runtime(let cause) { #expect(cause.code == .capacityExceeded) } catch { throw error }
    }
}

import MechanicsDeformingContact
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ContactPublicationTests {
    @Test func actualInitialHistoryCancellationCannotPublishMapperOrState() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("The cancellation fixture requires Mutex availability.");return }
        let snapshot=try DeformingFixtures.selfMoving(),witness=try DeformingFixtures.selfWitness(snapshot)
        let pair=try DeformingFixtures.pair()
        for stateOperation in [false,true] {
            let flag=ContactCancellationOwner()
            let mapper=MaterialSurfaceForceMapper(laws:CancellingHistoryLaw(afterHistory:{flag.cancel()}))
            let policy=try DeformingFixtures.policy(cancellation:{flag.cancelled()})
            var work=try DeformingFixtures.work(),law=try DeformingFixtures.lawWork()
            do {
                if stateOperation {
                    _=try ValueSurfaceContactTransactions(mapper:mapper).initialState(snapshot,
                        bindings:[SurfaceContactBinding(key:"self",witness:witness,pair:pair,currentObstacle:nil)],
                        policy:policy,work:&work,lawWork:&law)
                } else {
                    _=try mapper.initialHistory(witness,key:"self",pair:pair,policy:policy,work:&work,lawWork:&law)
                }
                Issue.record("Cancelled history was published.")
            } catch DeformingContactError.cancelled {
                #expect(flag.cancelled())
                #expect(law.operations > 0)
            } catch { throw error }
        }
    }

    @Test func directMaterialPointEnforcesCurrentCellPolicy() throws {
        let snapshot=try DeformingFixtures.selfMoving()
        let point=try SurfaceMaterialPoint(feature:SurfaceFeatureID(cell:101,oppositeNode:1),
            barycentric:[1,0,0],sumTolerance:1e-10)
        var work=try DeformingFixtures.work()
        do {
            _=try TetrahedralBoundaryUpdater().point(point,in:snapshot,policy:DeformingFixtures.policy(cells:1),work:&work)
            Issue.record("A previous admission bypassed the current cell policy.")
        } catch DeformingContactError.capacityExceeded { #expect(work.operations == 0) }
        catch { throw error }
    }
}

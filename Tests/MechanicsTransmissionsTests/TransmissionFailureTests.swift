import MechanicsCore
import MechanicsConstraints
import MechanicsTransmissions
import Testing

@Suite(.timeLimit(.minutes(1)))
struct TransmissionFailureTests {
    @Test func closedNetworkContradictionAndOriginalSpeedMismatchAreRejected() throws {
        let rows=[TransmissionRelation(id:1,kind:.externalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:0,phaseScale:1)),
            TransmissionRelation(id:2,kind:.externalGear(first:1,second:2,firstTeeth:40,secondTeeth:20,phase:0,phaseScale:1)),
            TransmissionRelation(id:3,kind:.rigidShaft(first:0,second:2,phase:1,phaseScale:1))]
        let network=try TransmissionFixtures.compile(rows,count:3)
        var work=try TransmissionFixtures.work(), constraint=try TransmissionFixtures.work()
        do { _=try AffineTransmissionOperator().assemble(network,initialPosition:[0,0,0],time:0,assemblyPolicy:TransmissionFixtures.assemblyPolicy(3),policy:TransmissionFixtures.policy(),work:&work,constraintWork:&constraint); Issue.record("Expected conflicting loop.") }
        catch let error as TransmissionError { if case .assembly(.inconsistent,let unavailable)=error { #expect(unavailable); #expect(error.failedSupplierWorkUnavailable); #expect(constraint.operations > 0) } else { Issue.record("Wrong failure: \(error)") } }
        let pair=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.externalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:0,phaseScale:1))])
        work=try TransmissionFixtures.work()
        do { _=try AffineTransmissionOperator().idealEfforts(pair,position:[1,-0.5],velocity:[1,1],normalizedEnergyMultipliers:[0],policy:TransmissionFixtures.policy(),work:&work); Issue.record("Zero multiplier must not hide incompatible velocity.") }
        catch let error as TransmissionError { if case .originalResidual=error {} else { Issue.record("Wrong failure: \(error)") } }
    }
    @Test func invalidCountsRadiusFramesAndDeferredFidelityDoNotProduceRows() throws {
        let compiler: any TransmissionCompiling=AffineTransmissionCompiler()
        let layout=try TransmissionFixtures.layout(), first=try TransmissionFixtures.port(0), second=try TransmissionFixtures.port(1)
        for kind in [TransmissionRelationKind.externalGear(first:0,second:1,firstTeeth:0,secondTeeth:40,phase:0,phaseScale:1),
                     .unsupported(.wormSelfLocking)] {
            var work=try TransmissionFixtures.work()
            do { _=try compiler.compile(id:1,layout:layout,ports:[first,second],relations:[TransmissionRelation(id:1,kind:kind)],minimumPosition:[-1,-1],maximumPosition:[1,1],minimumTime:0,maximumTime:1,policy:TransmissionFixtures.policy(),work:&work); Issue.record("Expected invalid/unsupported law.") }
            catch let error as TransmissionError { switch error { case .invalidInput,.unsupportedFidelity: break; default: Issue.record("Wrong failure: \(error)") } }
        }
        var work=try TransmissionFixtures.work()
        do { _=try compiler.compile(id:1,layout:layout,ports:[first,TransmissionFixtures.port(1,frame:"other")],relations:[TransmissionRelation(id:1,kind:.rigidShaft(first:0,second:1,phase:0,phaseScale:1))],minimumPosition:[-1,-1],maximumPosition:[1,1],minimumTime:0,maximumTime:1,policy:TransmissionFixtures.policy(),work:&work); Issue.record("Expected frame mismatch.") }
        catch let error as TransmissionError { if case .frameMismatch=error {} else { Issue.record("Wrong failure: \(error)") } }
        do { _=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.rackPinion(pinion:0,rack:1,radius:0,travelSign:1,phase:0,phaseScale:1))],rack:true); Issue.record("Expected radius failure.") }
        catch let error as TransmissionError { if case .invalidInput=error {} else { Issue.record("Wrong failure: \(error)") } }
    }
    @Test func capacityMetadataStorageAndCancellationAreBounded() throws {
        let compiler: any TransmissionCompiling=AffineTransmissionCompiler(), layout=try TransmissionFixtures.layout()
        let rows=[TransmissionRelation(id:1,kind:.rigidShaft(first:0,second:1,phase:0,phaseScale:1))]
        let normal=[try TransmissionFixtures.port(0),try TransmissionFixtures.port(1)]
        for mode in 0..<4 {
            var work=try TransmissionFixtures.work(storage:mode == 2 ? 1 : 200_000,operations:mode == 1 ? 100 : 2_000_000)
            let ports=mode == 1 ? [try TransmissionFixtures.port(0,frame:String(repeating:"a",count:10_000)),try TransmissionFixtures.port(1,frame:String(repeating:"a",count:10_000))] : normal
            let policy=try TransmissionFixtures.policy(maximumPorts:mode == 0 ? 1 : 10,cancelled:{mode == 3})
            do { _=try compiler.compile(id:1,layout:layout,ports:ports,relations:rows,minimumPosition:[-1,-1],maximumPosition:[1,1],minimumTime:0,maximumTime:1,policy:policy,work:&work); Issue.record("Expected bounded failure.") }
            catch let error as TransmissionError { switch error { case .capacityExceeded,.numerical,.cancelled: break; default: Issue.record("Wrong failure: \(error)") } }
        }
    }
    @Test func staleModelAndLayoutBindingsCannotProduceIdealEfforts() throws {
        let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.rigidShaft(first:0,second:1,phase:0,phaseScale:1))])
        for layoutChanged in [false,true] {
            var work=try TransmissionFixtures.work()
            let policy=try TransmissionFixtures.policy(expectedModelRevision:layoutChanged ? 9 : 10,expectedLayoutRevision:layoutChanged ? 8 : 7)
            do { _=try AffineTransmissionOperator().idealEfforts(network,position:[0,0],velocity:[0,0],normalizedEnergyMultipliers:[1],policy:policy,work:&work); Issue.record("Expected stale binding.") }
            catch let error as TransmissionError { if case .staleBinding=error {} else { Issue.record("Wrong failure.") } }
        }
    }
    @Test func staleContinuationAndFailedSupplierRetainExplicitFailure() throws {
        let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.rigidShaft(first:0,second:1,phase:0,phaseScale:1))])
        var work=try TransmissionFixtures.work(), constraint=try TransmissionFixtures.work(storage:1)
        do { _=try AffineTransmissionOperator().assemble(network,initialPosition:[1,0],time:0,assemblyPolicy:TransmissionFixtures.assemblyPolicy(2),policy:TransmissionFixtures.policy(),work:&work,constraintWork:&constraint); Issue.record("Expected supplier failure.") }
        catch let error as TransmissionError { if case .assembly(.numerical,let unavailable)=error { #expect(unavailable); #expect(constraint.operations > 0) } else { Issue.record("Wrong failure: \(error)") } }
        let law=try BacklashLaw(id:1,revision:1,halfClearance:0.1,stiffness:100,damping:1,maximumAbsPhase:1,energyScale:1)
        let bad=BacklashContinuation(networkID:network.id,rowID:1,layoutRevision:7,modelRevision:9,lawID:1,lawRevision:0,time:0,phase:0,storedEnergy:0,branch:.free)
        work=try TransmissionFixtures.work()
        do { _=try PassiveTransmissionEvaluator().backlash(network,rowIndex:0,position:[0,0],velocity:[0,0],time:1,law:law,accepted:bad,policy:TransmissionFixtures.policy(),work:&work); Issue.record("Expected stale law state.") }
        catch let error as TransmissionError { if case .staleContinuation=error {} else { Issue.record("Wrong failure: \(error)") } }
    }
}

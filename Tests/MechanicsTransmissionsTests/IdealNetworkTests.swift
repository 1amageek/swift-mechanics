import MechanicsCore
import MechanicsConstraints
import MechanicsTransmissions
import Testing

@Suite(.timeLimit(.minutes(1)))
struct IdealNetworkTests {
    @Test func externalInternal20to40RetainPhaseSignedRatioAndEffortPower() throws {
        let service: any TransmissionNetworkOperating=AffineTransmissionOperator()
        for internalMesh in [false,true] {
            let kind: TransmissionRelationKind=internalMesh ? .internalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:4,phaseScale:2) : .externalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:4,phaseScale:2)
            let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:kind)])
            let sign=internalMesh ? 1.0 : -1.0
            var work=try TransmissionFixtures.work()
            let result=try service.idealEfforts(network,position:[1,sign*0.4],velocity:[2,sign],normalizedEnergyMultipliers:[4],policy:TransmissionFixtures.policy(),work:&work)
            #expect(result.generalizedEfforts == [40,-sign*80])
            #expect(TransmissionFixtures.close(result.totalPower,0))
            #expect(network.equations.rows[0].linear == [10,-sign*20])
            #expect(result.originalPhaseResidual <= 1e-8)
        }
    }
    @Test func opposedShaftAxesChangeCoordinateSignWithoutChangingWorldConvention() throws {
        let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.externalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:0,phaseScale:1))],flipSecond:true)
        var work=try TransmissionFixtures.work()
        let result=try AffineTransmissionOperator().idealEfforts(network,position:[1,0.5],velocity:[2,1],normalizedEnergyMultipliers:[1],policy:TransmissionFixtures.policy(),work:&work)
        #expect(result.generalizedEfforts == [20,-40])
        #expect(TransmissionFixtures.close(result.ports[1].axisInReference.z,-1))
        #expect(TransmissionFixtures.close(result.ports[1].wrenchAboutReferenceOrigin.torque.z,40))
    }
    @Test func rackPinionHasDimensionedTravelAndForceTorqueWork() throws {
        let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.rackPinion(pinion:0,rack:1,radius:0.1,travelSign:1,phase:0.05,phaseScale:0.2))],rack:true)
        var work=try TransmissionFixtures.work()
        let result=try AffineTransmissionOperator().idealEfforts(network,position:[2,0.25],velocity:[2,0.2],normalizedEnergyMultipliers:[2],policy:TransmissionFixtures.policy(),work:&work)
        #expect(network.physicalRows[0].phaseDimension == .length)
        #expect(TransmissionFixtures.close(result.generalizedEfforts[0],-1)); #expect(TransmissionFixtures.close(result.generalizedEfforts[1],10))
        #expect(TransmissionFixtures.close(result.ports[1].wrenchAboutReferenceOrigin.force.x,10))
        #expect(TransmissionFixtures.close(result.ports[1].wrenchAboutReferenceOrigin.torque.z,-10))
        let travel=0.1*2*Double.pi, torqueWork = -1*2*Double.pi, rackWork=10*travel
        #expect(TransmissionFixtures.close(torqueWork+rackWork,0))
    }
    @Test func idlerClosedNetworkAssemblesAllRowsAndReportsRedundantReactionMap() throws {
        let relations=[TransmissionRelation(id:1,kind:.externalGear(first:0,second:1,firstTeeth:20,secondTeeth:40,phase:0,phaseScale:1)),
            TransmissionRelation(id:2,kind:.externalGear(first:1,second:2,firstTeeth:40,secondTeeth:20,phase:0,phaseScale:1)),
            TransmissionRelation(id:3,kind:.rigidShaft(first:0,second:2,phase:0,phaseScale:1))]
        let network=try TransmissionFixtures.compile(relations,count:3)
        var work=try TransmissionFixtures.work(), constraint=try TransmissionFixtures.work()
        let service: any TransmissionNetworkOperating=AffineTransmissionOperator()
        let result=try service.assemble(network,initialPosition:[0.8,-0.2,0.6],time:0,assemblyPolicy:TransmissionFixtures.assemblyPolicy(3),policy:TransmissionFixtures.policy(),work:&work,constraintWork:&constraint)
        let q=result.assembly.position
        #expect(TransmissionFixtures.close(q[0],2.0/3)); #expect(TransmissionFixtures.close(q[1],-1.0/3)); #expect(TransmissionFixtures.close(q[2],2.0/3))
        #expect(result.assembly.rank.rank == 2); #expect(result.assembly.rank.reactionNullity == 1); #expect(result.originalPhysicalPhaseResidual <= 1e-8)
        #expect(constraint.operations > 0)
    }
    @Test func willisAndOpenCrossedPulleyEquationsConserveConjugatePower() throws {
        let planetary=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.planetary(sun:0,ring:1,carrier:2,sunTeeth:20,ringTeeth:40,phase:0,phaseScale:1))],count:3)
        var work=try TransmissionFixtures.work()
        let result=try AffineTransmissionOperator().idealEfforts(planetary,position:[3,0,1],velocity:[3,0,1],normalizedEnergyMultipliers:[0.1],policy:TransmissionFixtures.policy(),work:&work)
        #expect(result.generalizedEfforts == [2,4,-6]); #expect(TransmissionFixtures.close(result.totalPower,0))
        for crossed in [false,true] {
            let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.pulley(first:0,second:1,firstRadius:0.1,secondRadius:0.2,crossed:crossed,phase:0,phaseScale:1))])
            work=try TransmissionFixtures.work(); let sign=crossed ? -1.0 : 1.0
            let response=try AffineTransmissionOperator().idealEfforts(network,position:[2,sign],velocity:[4,sign*2],normalizedEnergyMultipliers:[10],policy:TransmissionFixtures.policy(),work:&work)
            #expect(TransmissionFixtures.close(response.totalPower,0)); #expect(response.generalizedEfforts == [1,-sign*2])
        }
    }
}

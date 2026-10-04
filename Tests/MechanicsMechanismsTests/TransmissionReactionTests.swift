import SwiftMechanics
import Testing

@Suite struct TransmissionReactionTests {
    @Test func actualTransmissionRowsTorqueAndVirtualPower() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(v:[2,-1]),system=try MechanismFixtures.system(model),layout=try MechanismFixtures.layout()
            var ports:[TransmissionPortBinding]=[]
            for (i,joint) in model.tree.joints.enumerated() {
                ports.append(try TransmissionPortBinding(coordinateIndex:i,coordinateID:layout.coordinateIDs[i],body:joint.childBody,joint:joint.id,
                    frame:model.tree.worldFrame,manifold:joint.manifold,jointToReference:.identity,layoutRevision:1,modelRevision:1))
            }
            let policy=try TransmissionPolicy(maximumCoordinates:8,maximumPorts:8,maximumRelations:8,expectedLayoutRevision:1,expectedModelRevision:1,
                geometryTolerance:1e-10,originalTolerance:1e-8,powerScale:1,powerTolerance:1e-8)
            var compilation=try MechanismFixtures.work()
            let network=try AffineTransmissionCompiler().compile(id:1,layout:layout,ports:ports,
                relations:[TransmissionRelation(id:1,kind:.externalGear(first:0,second:1,firstTeeth:1,secondTeeth:2,phase:0,phaseScale:1))],
                minimumPosition:[-100,-100],maximumPosition:[100,100],minimumTime:0,maximumTime:10,policy:policy,work:&compilation)
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work(),t=try MechanismFixtures.work()
            let result=try MassWeightedMechanismSolver().acceleration(system,sample:MechanismFixtures.sample(),drive:[6,0],policy:MechanismFixtures.policy(),
                work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l)
            let diagnosis=try AffineMechanismTransmissionDiagnostics().diagnose(network,position:[0,0],velocity:[2,-1],motion:result,policy:policy,work:&t)
            #expect(abs(diagnosis.ports[0].generalizedEffort+2) < 1e-9);#expect(abs(diagnosis.ports[1].generalizedEffort+4) < 1e-9)
            #expect(abs(diagnosis.totalPower) < 1e-9)
            #expect(abs(diagnosis.ports[0].wrenchAboutReferenceOrigin.torque.z+2) < 1e-9)
            #expect(diagnosis.ports[0].binding.frame == model.tree.worldFrame)
            #expect(diagnosis.originalPhaseResidual < 1e-9 && diagnosis.originalSpeedResidual < 1e-9)
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}

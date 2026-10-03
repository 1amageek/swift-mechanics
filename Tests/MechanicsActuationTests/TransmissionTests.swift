import Testing
import MechanicsActuation
import MechanicsCore
import MechanicsLoads
import MechanicsJoints

@Suite struct TransmissionTests {
    @Test func multiDOFAffineVirtualAndPrescribedWork() throws {
        let binding=try ActuationFixtures.binding(),frame=binding.frame,service:any ActuationTransmitting=ReferenceActuationTransmitter(mapper:LoadMapper())
        var work=try ActuationFixtures.work(),numeric=try ActuationFixtures.numerical()
        let row=try AffineTransmission(model:binding.model,frame:frame,outputCoordinate:.rotation,inputCoordinates:[.rotation,.translation],gradient:[2,-0.5],prescribedRate:1,work:&work)
        let response=try service.affine(row,model:binding.model,frame:frame,effort:4,rate:[3,2],tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric)
        #expect(response.efforts == [8,-2] && response.virtualPower == 20 && response.prescribedPower == 4 && response.actualPower == 24)
        #expect(response.balanceResidual == 0)
        #expect(throws:ActuationError.frameMismatch) { try service.affine(row,model:binding.model,frame:ActuationFixtures.id(.frame,"other"),effort:4,rate:[3,2],tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
        #expect(throws:ActuationError.outsideDomain) { try AffineTransmission(model:binding.model,frame:frame,outputCoordinate:.rotation,inputCoordinates:[.rotation],gradient:[0],prescribedRate:0,work:&work) }
    }
    @Test func movingStraightTendonGeometryDerivativeAndPower() throws {
        let frame=try ActuationFixtures.id(.frame,"world"),router:any CableRouting=StraightCableRouter(),transmitter:any ActuationTransmitting=ReferenceActuationTransmitter(mapper:LoadMapper())
        var work=try ActuationFixtures.work(),numeric=try ActuationFixtures.numerical(),loads=LoadWork(budget:try LoadBudget(maximumWork:1000,maximumScalars:100))
        func route(_ q:Double) throws -> CableRouteResponse {
            let points=try [RoutePoint(frame:frame,position:.zero,coordinateColumns:[.zero]),RoutePoint(frame:frame,position:Vector3(1,q,0),coordinateColumns:[.unitY],prescribedVelocity:.unitX)]
            return try router.evaluate(points:points,branch:.straightWaypoints,coordinateRate:[2],secondDerivativeDirection:[1],minimumSegmentLength:1e-8,work:&loads)
        }
        let q=0.75,h=1e-5,r=try route(q),plus=try route(q+h),minus=try route(q-h)
        let response=try transmitter.tendon(r,frame:frame,tension:5,rate:[2],tolerance:ActuationFixtures.tolerance(),work:&work,loads:&loads,numerical:&numeric)
        #expect(abs(response.efforts[0]+5*(plus.length-minus.length)/(2*h)) < 1e-9)
        #expect(abs(response.efforts[0]+5*q/(1+q*q).squareRoot()) < 1e-12)
        #expect(abs(response.prescribedPower+5/(1+q*q).squareRoot()) < 1e-12)
        #expect(abs(response.virtualPower+response.prescribedPower-response.actualPower) < 1e-12)
        #expect(throws:ActuationError.residualMismatch) { try transmitter.tendon(r,frame:frame,tension:5,rate:[3],tolerance:ActuationFixtures.tolerance(),work:&work,loads:&loads,numerical:&numeric) }
    }
    @Test func actualBodyPointJacobianLoadPowerAndSupplierBudget() throws {
        let model=try ActuationFixtures.model(),body=try ActuationFixtures.id(.body,"child"),calculator:any KinematicJacobianComputing=KinematicJacobianCalculator()
        let jacobian=try calculator.point(body:body,bodyLocalPoint:.unitX,snapshot:model.initialSnapshot)
        let load=try FramedPointLoad(body:body,frame:model.descriptor.worldFrame,point:jacobian.pointWorld,forces:ForceParts(active:Vector3(0,4,0)))
        let mapper:any ActuationTransmitting=ReferenceActuationTransmitter(mapper:LoadMapper())
        var work=try ActuationFixtures.work(),loads=LoadWork(budget:try LoadBudget(maximumWork:100,maximumScalars:10))
        let response=try mapper.point(load,jacobian:jacobian,rate:[2],work:&work,loads:&loads)
        #expect(response.values == [4] && response.power.virtual == 8 && response.power.actual == 8)
        #expect(loads.consumed == 2 && work.used == 1)
        loads=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:10))
        #expect(throws:ActuationError.load(.workExhausted)) { try mapper.point(load,jacobian:jacobian,rate:[2],work:&work,loads:&loads) }
    }
}

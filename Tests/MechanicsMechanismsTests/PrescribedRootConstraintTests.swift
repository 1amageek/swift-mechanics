import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct PrescribedRootConstraintTests {
    @Test func genuineRootIdentityRowsSolveFullMassAndRetainZeroGeometryOnBothCharts() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] {
                let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12),ip=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
                let body=try EntityID(kind:.body,key:"root"),frame=try EntityID(kind:.frame,key:"root-frame"),world=try EntityID(kind:.frame,key:"world")
                let pose=RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:0.4),translation:try Vector3(1,2,0))
                let p2=try MassProperties2D(mass:2,centerX:0.4,centerY:-0.3,polarInertiaAtCenter:5)
                let p3=try MassProperties3D(mass:2,centerOfMass:Vector3(0.4,-0.3,0),inertiaAtCenter:Matrix3(3,0,0,0,4,0,0,0,5),policy:ip)
                let raw:MechanicalBody
                if planar { raw = .planar(try BodyRecord2D(id:body,frame:frame,mode:.dynamic,bodyToWorld:PlanarPose(x:1,y:2,angle:0.4),representations:BodyRepresentations(),inertia:InertialRepresentation2D(properties:p2,provenance:SourceProvenance(source:"root",revision:1),quality:.exact))) }
                else { raw = .spatial(try BodyRecord3D(id:body,frame:frame,mode:.dynamic,bodyToWorld:pose,representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:p3,provenance:SourceProvenance(source:"root",revision:1),quality:.exact))) }
                let base=planar ? BaseLayout.planarFloating : .spatialFloating
                let tree=try KinematicTree(bodies:[raw.kinematicBody()],joints:[],root:body,rootBase:base,worldFrame:world,revision:1,capacity:KinematicCapacity(maximumBodies:1,maximumVelocities:6,maximumJacobianScalars:36))
                var work=try MechanismFixtures.work()
                let motionPolicy=try PrescribedMotionPolicy(maximumSamples:1,maximumIdentifierBytes:100,maximumMetadataBytes:6000)
                let law=try AnalyticPrescribedMotion(frame:frame,parentFrame:world,referenceTime:0,initialPose:pose,translationRate:Vector3(0.4,-0.2,0),translationAcceleration:Vector3(0.3,0.2,0),rotationAxis:.unitZ,angularRate:0.2,angularAcceleration:0.3,minimumTime:0,maximumTime:1,maximumIdentifierBytes:100)
                let program=try PrescribedBaseMotionProgram(law:law,layout:base,policy:motionPolicy,work:&work),sample=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:0.2,policy:motionPolicy,work:&work)
                let state=try KinematicState(revision:1,time:0.2,q:sample.q,v:sample.v,acceleration:sample.a)
                let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:state,policy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1))
                let input:PhysicalRigidDynamicsInput
                if planar { input=try PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:[PlanarRigidBodyInertia(body:body,frame:frame,properties:p2)],gravity:nil)) }
                else { input=try PhysicalRigidDynamicsInput(spatial:RigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:[RigidBodyInertia(body:body,frame:frame,properties:p3)],gravity:nil)) }
                var loads=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
                let system=try RigidEquationKernel().assemble(input,admission:MechanismFixtures.admission(),loadWork:&loads,work:&work),n=sample.v.count
                let dims:[PhysicalDimension]=planar ? [.length,.length,.angle] : [.length,.length,.length,.angle,.angle,.angle]
                let scales=(0..<n).map { 1+Double($0)/4 },layout=try ConstraintCoordinateLayout(coordinateIDs:(0..<n).map { UInt64($0+1) },dimensions:dims,scales:scales,timeScale:3,revision:1)
                let geometry=VelocityConstraintSample(layout:layout,rowIDs:[],rows:[],drift:[],accelerationBias:[],isIntegrable:true)
                let p=try MechanismFixtures.policy(),c=p.constraints
                // Independent inverse-mass columns do not guarantee a bit-symmetric original Gram.
                let constraints=try ConstraintSolvePolicy(evaluation:c.evaluation,diagonalMetric:[Double](repeating:1,count:n),energyScale:c.energyScale,rankPolicy:c.rankPolicy,rankRelativeTolerance:c.rankRelativeTolerance,originalResidualTolerance:c.originalResidualTolerance,maximumCorrection:c.maximumCorrection,nonlinear:c.nonlinear,linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:c.linearTolerance)
                let policy=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:p.dynamics.capability,linearTolerance:p.dynamics.linearTolerance,coordinateScales:scales,energyScale:7,timeScale:3),constraints:constraints,maximumCoordinates:8,maximumRows:8,originalTolerance:1e-8)
                let constraint=try PrescribedRootConstraint(system:system,geometry:geometry,base:sample,rowIDs:(0..<n).map { UInt64(101+$0) },policy:policy,work:&work)
                #expect(constraint.geometry.rowIDs.isEmpty && constraint.dynamicCoordinates.isEmpty)
                for i in 0..<n { #expect(constraint.sample.rows[i*n+i] == 1 && constraint.sample.drift[i] == -sample.v[i]*3/scales[i]);#expect(constraint.sample.accelerationBias[i] == -sample.a[i]*3*3/scales[i]) }
                let solver:any PrescribedRootMechanismSolving=MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())
                var dynamics=try MechanismFixtures.work(),rank=try MechanismFixtures.work(),linear=try MechanismFixtures.work()
                let result=try solver.acceleration(constraint,drive:[Double](repeating:0,count:n),policy:policy,work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
                #expect(result.system === system && result.motion.values == sample.a && result.motion.rank.rank == n)
                let geometric=try constraint.geometricReaction(result.motion,work:&work)
                #expect(geometric == [Double](repeating:0,count:n))
                let partition=try RigidEquationKernel().partitionedPower(system,acceleration:result.motion.values,knownCoordinates:constraint.knownCoordinates,drive:[Double](repeating:0,count:n),geometricReaction:geometric,policy:policy.dynamics,work:&work)
                for i in 0..<n { #expect(abs(partition.rootActuationEffort[i]-result.motion.generalizedReaction[i]) < 1e-9) }
                let wrong=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:0.3,policy:motionPolicy,work:&work)
                do throws(MechanismError) { _=try PrescribedRootConstraint(system:system,geometry:geometry,base:wrong,rowIDs:constraint.sample.rowIDs,policy:policy,work:&work);Issue.record("Stale source accepted") }
                catch { if case .staleBinding=error {} else { Issue.record("Wrong source failure") } }
            }
        }
    }
}

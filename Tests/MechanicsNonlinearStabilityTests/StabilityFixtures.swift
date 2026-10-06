import SwiftMechanics

struct StabilityFixtures {
    static func id(_ kind: EntityKind,_ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func limits() throws -> EquilibriumLimits { try EquilibriumLimits(coordinates:8,rows:4,cases:1000,identifierBytes:1000,bodies:16) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-10,relative:1e-10) }
    static func work(storage: Int=500000,operations: Int=100000000,iterations: Int=10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func nonlinear(iterations: Int=100) throws -> NonlinearPolicy<Double> {
        try NonlinearPolicy(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-10),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),
            tolerance:LinearTolerance(absoluteResidual:1e-11,relativeResidual:0,pivotThreshold:1e-13),referenceScale:1,minimumDirectionNorm:0,
            derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,maximumFactorEntries:10000,estimateCondition:false,
            budget:NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:iterations))
    }
    static func policy(_ n: Int=3,cancel: @escaping @Sendable () -> Bool={false},spectralCancel: @escaping @Sendable () -> Bool={false},
                       nonlinearIterations: Int=100,criticalIterations: Int=80,maximumPoints: Int=1000) throws -> NonlinearStabilityPolicy {
        let eq=try EquilibriumPolicy(limits:limits(),nonlinear:nonlinear(iterations:nonlinearIterations),physicalForceTolerances:[Double](repeating:1e-8,count:n),
            constraintTolerance:1e-9,reactionSelection:.requireUnique)
        let evidence=try EquilibriumLinearizationPolicy(limits:limits(),capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            tolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13),displacementProbe:1e-5,parameterProbe:1e-5,
            derivativeAbsoluteTolerances:[Double](repeating:1e-7,count:n),derivativeRelativeTolerance:1e-6,constraintTolerance:1e-9,inertialAbsoluteTolerances:[Double](repeating:1e-9,count:n))
        let spectrum=try ComplexSpectrumPolicy(maximumDimension:8,maximumQRIterations:2000,deflationTolerance:1e-13,eigenvectorPivotThreshold:1e-13,
            originalResidualTolerance:1e-8,isCancelled:spectralCancel)
        let dynamics=try DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:16,maximumVelocities:8,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:tolerance(),linearVelocityTolerance:tolerance())
        return try NonlinearStabilityPolicy(equilibrium:eq,evidence:evidence,spectrum:spectrum,dynamics:dynamics,loadBudget:LoadBudget(maximumWork:100000,maximumScalars:100000),
            parameterScale:1,arcTolerance:1e-9,spectralTolerance:1e-7,zeroStiffnessTolerance:1e-7,loadProjectionTolerance:1e-5,minimumMassPivot:1e-12,
            maximumArcStep:0.2,maximumCorrection:0.3,maximumAcceptedPoints:maximumPoints,maximumCriticalIterations:criticalIterations,criticalWidth:1e-7,isCancelled:cancel)
    }
    static func source(linear: [Double]=[-1,-1,1],cubic: [Double]=[1,1,0],load: [Double]=[1,1,0],rows: [[Double]]=[[-1,-1,1]],
                       nonlinearRow: Bool=false,masses: [Double]?=nil,work: inout NumericalWork) throws -> NonlinearStabilitySource {
        let n=linear.count,compiled=try compiled(n,masses:masses)
        let joints=compiled.tree.joints.filter{$0.manifold.velocityCount>0}.map{$0.id}
        let chart=try StaticCoordinateChart(stamp:compiled.stamp,frame:compiled.tree.worldFrame,coordinateIDs:(0..<n).map{UInt64($0+1)},
            joints:joints,dimensions:[PhysicalDimension](repeating:.length,count:n),scales:[Double](repeating:1,count:n),limits:limits())
        let model=try StaticForceModel(identity:"coupled-springs",chart:chart,law:.springs(linear:linear,cubic:cubic,constant:[Double](repeating:0,count:n),loadDirection:load),
            minimumPosition:[Double](repeating:-3,count:n),maximumPosition:[Double](repeating:3,count:n),parameterIdentity:"load",minimumParameter:-10,maximumParameter:10,energyScale:1,limits:limits())
        let branch=try EquilibriumBranch(identity:"explicit-branch",minimumPosition:model.minimumPosition,maximumPosition:model.maximumPosition,maximumNormalizedStep:0.3,limits:limits())
        var records:[QuadraticConstraint]=[]
        for r in rows.indices { var H=[Double](repeating:0,count:n*n);if nonlinearRow { H[0]=1 }
            records.append(QuadraticConstraint(id:UInt64(r+10),constant:0,linear:rows[r],hessian:H,timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:n)))
        }
        let system=try QuadraticConstraintSystem(layout:ConstraintCoordinateLayout(coordinateIDs:chart.coordinateIDs,dimensions:chart.dimensions,scales:chart.scales,timeScale:1,revision:chart.stamp.revision),
            rows:records,minimumPosition:model.minimumPosition,maximumPosition:model.maximumPosition,minimumTime:-1,maximumTime:1)
        let cp=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:4,expectedLayoutRevision:chart.stamp.revision),
            diagonalMetric:[Double](repeating:1,count:n),energyScale:1,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-12,originalResidualTolerance:1e-9,
            maximumCorrection:0.3,nonlinear:nonlinear(),linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-11,relativeResidual:1e-11,pivotThreshold:1e-13))
        let constraints=records.isEmpty ? nil : StaticConstraints(system:system,policy:cp,responseBudget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:0))
        return try NonlinearStabilitySource(model:model,constraints:constraints,compiled:compiled,branch:branch,time:0,limits:limits(),work:&work)
    }
    static func compiled(_ n: Int,masses: [Double]?) throws -> CompiledMechanicalModel {
        let provenance=try SourceProvenance(source:"stability-fixture",revision:1),ip=try InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0)
        var bodies:[MechanicalBody]=[],joints:[MechanicalJoint]=[]
        for i in -1..<n {
            let name=i<0 ? "root" : "child-\(i)"
            let properties=try MassProperties3D(mass:i<0 ? 1 : masses?[i] ?? 1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:ip)
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:i<0 ? .static : .dynamic,bodyToWorld:.identity,
                representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,provenance:provenance,quality:.exact))))
            if i>=0 {
                let record=try JointRecord(id:id(.joint,"joint-\(i)"),parentBody:id(.body,"root"),childBody:id(.body,name),
                    parentAnchor:JointAnchor(frame:id(.frame,"parent-\(i)"),placement:.fixed(.identity)),childAnchor:JointAnchor(frame:id(.frame,"anchor-\(i)"),placement:.fixed(.identity)),
                    manifold:JointManifold(.prismatic(axis:.unitY)))
                joints.append(MechanicalJoint(record:record,authority:.dynamicState))
            }
        }
        let zero=[Double](repeating:0,count:n)
        let descriptor=try MechanicalDescriptor(identity:"stability-fixture",revision:1,bodies:bodies,joints:joints,root:id(.body,"root"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:1,time:0,q:zero,v:zero,acceleration:zero),representationRequirements:[],features:[],extensions:[])
        let cp=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:16,maximumVelocities:8,maximumJacobianScalars:10000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:tolerance(),rotationTolerance:tolerance(),maximumRecords:1000,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,maximumDependencyEntries:10000,
            maximumExtensionRecords:0,maximumDiagnostics:10,extensionBudget:NumericalBudget(scalarStorage:1000,arithmeticOperations:10000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:cp)
    }
    static func seed(u: Double,v: Double) -> [Double] { [u+v,u-v,2*u] }
    static func parameter(u: Double,v: Double) -> Double { u+u*u*u+3*u*v*v }
    static func direction(u: Double,sign: Double) -> [Double] {
        let v=sign*(1-3*u*u).squareRoot(),dv = -3*u/v
        return [1+dv,1-dv,2,4-24*u*u]
    }
}

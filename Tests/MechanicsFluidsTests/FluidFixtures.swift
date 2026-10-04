import SwiftMechanics
import Testing
struct FluidFixtures {
    static func policy(cancel: @escaping @Sendable () -> Bool = { false }) throws -> FluidPolicy {
        try FluidPolicy(forceAbsolute:1e-10,forceRelative:1e-10,pressureGradientAbsolute:1e-8,
            energyAbsolute:1e-10,energyRelative:1e-10,powerAbsolute:1e-10,powerRelative:1e-10,
            linearTolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-11,pivotThreshold:1e-14),isCancelled:cancel)
    }
    static func work() throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:10000)) }
    static func channel(cells:Int=8,rho:Double=1,mu:Double=1,gy:Double=0,model:ModelStamp=ModelStamp(identity:"fluid-carrier",revision:1)) throws -> FluidChannel {
        try FluidChannel(id:"parallel-plate",revision:1,model:model,frame:EntityID(kind:.frame,key:"world"),
            source:SourceProvenance(source:"fluid-fixture",revision:1),boundaryLaw:"held-wall-source",boundaryRevision:1,
            height:1,wallArea:2,density:rho,viscosity:mu,accelerationX:0,accelerationY:gy,cells:cells,
            limits:FluidLimits(maximumCells:64,maximumMetadataBytes:1024,maximumSpeed:100,maximumPressure:1e7,maximumSource:10000,maximumStep:10))
    }
    static func boundary(lower:Double=0,upper:Double=0,gradient:Double=0,pressure:Double=0) throws -> FluidBoundary {
        try FluidBoundary(lowerSpeed:lower,upperSpeed:upper,pressureGradientX:gradient,lowerGaugePressure:pressure)
    }
    static func state(channel:FluidChannel,boundary:FluidBoundary,velocities:[Double]?=nil,time:Double=0) throws -> FluidState {
        var w=try work()
        return try ReferenceFluidFieldBuilder().makeState(channel:channel,boundary:boundary,time:time,
            velocities:velocities ?? [Double](repeating:0,count:channel.cells),policy:policy(),work:&w)
    }
    static func solver() -> ReferenceViscousChannelSolver { ReferenceViscousChannelSolver(linear:ReferenceLinearSolver<Double>(),fields:ReferenceFluidFieldBuilder()) }
    static func failure(_ expected:FluidError,_ body:() throws(FluidError)->Void) {
        do throws(FluidError) { try body(); Issue.record("Expected fluid failure") } catch { #expect(error == expected) }
    }
    static func model(revision:UInt64=1) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
        let inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let source=try SourceProvenance(source:"carrier",revision:revision)
        let inertia=try InertialRepresentation3D(properties:MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:inertiaPolicy),provenance:source,quality:.exact)
        let root=try BodyRecord3D(id:EntityID(kind:.body,key:"root"),frame:EntityID(kind:.frame,key:"root-frame"),mode:.static,
            bodyToWorld:.identity,representations:BodyRepresentations(),inertia:inertia)
        let descriptor=try MechanicalDescriptor(identity:"fluid-carrier",revision:revision,bodies:[.spatial(root)],joints:[],root:root.id,
            rootBase:.fixed,rootAuthority:.fixed,worldFrame:EntityID(kind:.frame,key:"world"),
            initialState:KinematicState(revision:revision,time:0,q:[],v:[],acceleration:[]),representationRequirements:[],features:[],extensions:[])
        let p=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:32,maximumJacobianScalars:1536),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-9,characteristicLengthMeters:1),
            inertiaPolicy:inertiaPolicy,translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,
            maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,maximumExtensionRecords:8,
            maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:p)
    }
}

import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal enum PlanarEvolutionFixtures {
    static func equation(_ fixture:GeometricEvolutionFourBar,torque:Double = 0.001,
                         kernel:any PhysicalRigidEquationComputing = RigidEquationKernel(),
                         solver:any PhysicalConstrainedMechanismSolving = MassWeightedMechanismSolver(
                            physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())) throws -> GeometricMechanismEquation {
        let geometry=try GeometricEvolutionFixtures.fourbarSystem(fixture),projection=try GeometricEvolutionFixtures.policy(3)
        let base=try NonlinearMechanismFixtures.policy(scales:geometry.layout.scales,gramLU:true)
        let policy=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:base.dynamics.capability,linearTolerance:base.dynamics.linearTolerance,
            coordinateScales:geometry.layout.scales,energyScale:7,timeScale:geometry.layout.timeScale),constraints:projection.constraints,
            maximumCoordinates:24,maximumRows:30,originalTolerance:1e-8)
        var drive=[Double](repeating:0,count:3);drive[fixture.crankIndex]=torque
        return try GeometricMechanismEquation(identity:"geometric-force-evolution",geometry:geometry,drive:drive,policy:policy,projection:projection,
            maximumStageChartCorrection:0.01,publicationBudget:GeometricEvolutionFixtures.work().budget,
            admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:50000,physicalKernel:kernel,physicalSolver:solver)
    }
    typealias Session=RuntimeSession<GeometricMechanismCheckpointHandler>
    static func session(_ equation:GeometricMechanismEquation,step:Double = 0.05) throws -> (Session,IntegrationContinuationProvider) {
        let (temporary,continuation)=try NonlinearMechanismFixtures.session(equation,step:step)
        let configuration=temporary.configuration;_ = temporary.shutdown()
        let base=ReferenceRuntimeCheckpointHandler(contributors:continuation,revisions:ReferenceModelRevisionUpdater())
        let handler=try GeometricMechanismCheckpointHandler(equations:equation,continuation:continuation,base:base,validationBudget:equation.publicationBudget)
        let initial=equation.model.descriptor.initialState
        return (try Session(model:equation.model,configuration:configuration,initialState:initial,
            contributors:[continuation.initialRecord(physical:initial,equations:equation)],seed:42,checkpoints:handler),continuation)
    }
}

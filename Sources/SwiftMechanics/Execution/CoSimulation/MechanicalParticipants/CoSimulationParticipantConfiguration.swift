public struct CoSimulationParticipantConfiguration: Sendable {
    public let identity: String
    public let plant: PrismaticControlPlant
    public let controller: SampledController
    public let clock: ControlClock
    public let initialActuator: ActuatorState
    public let seed: UInt64
    public let control: ControlPolicy
    public let observation: ObservationPolicy
    public let encoderBudget: NumericalBudget
    public init(identity: String, maximumIdentityBytes: Int, plant: PrismaticControlPlant,
                controller: SampledController, clock: ControlClock, initialActuator: ActuatorState,
                seed: UInt64, control: ControlPolicy, observation: ObservationPolicy,
                encoderBudget: NumericalBudget) throws(CoSimulationFailure) {
        guard maximumIdentityBytes > 0, !identity.isEmpty else { throw .refusal(.invalidInput) }
        var identityBytes=0
        for _ in identity.utf8 {
            guard identityBytes < maximumIdentityBytes else { throw .refusal(.capacity) }
            identityBytes += 1
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Other controller/filter/drive modes reach public participant admission.
        // Their actual applied force and state evolution need a distinct physical coupling certificate before success.
        guard controller.law == .servo, controller.mode == .effort, initialActuator.mode == .effort,
              controller.servo.filterTimeConstant == 0 else { throw .refusal(.unsupportedDomain) }
        let servo = controller.servo, domain = servo.binding.stateDomain
        guard servo.binding == plant.port.binding, initialActuator.binding == plant.port.binding,
              domain.secondaryLower <= -servo.effortLimit, domain.secondaryUpper >= servo.effortLimit,
              control.integration.budget.maximumAttempts == 1, control.integration.budget.maximumAcceptedSteps == 1 else { throw .refusal(.unsupportedDomain) }
        self.identity=identity; self.plant=plant; self.controller=controller; self.clock=clock
        self.initialActuator=initialActuator; self.seed=seed; self.control=control
        self.observation=observation; self.encoderBudget=encoderBudget
    }
}

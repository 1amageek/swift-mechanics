import ExternalCommandsQualificationSupport

@main struct ExternalCommandsQualification {
    static func main() throws {
        try ExternalCommandQualificationCases.delayedLinearAndExactSI()
        print("External commands original delay, linear weights, exact timestamp and SI witness passed")
        try ExternalCommandQualificationCases.holdRestorePruneAndReplay()
        print("External commands original hold, restore, prune and exact replay witness passed")
        try ExternalCommandQualificationCases.actualServoMechanicalWork()
        print("External commands real actuator force, velocity, mechanical work and sequence witness passed")
        try ExternalCommandQualificationCases.arrivalAgeGapAndClockRefusals()
        try ExternalCommandQualificationCases.originalIdentityUnitsOrderAndFailureWork()
        try ExternalCommandQualificationCases.capacitiesAndOverflow()
        print("External commands source, arrival, units, failure, capacity and known work witnesses passed")
        print("External commands six selected synchronous public cases completed")
    }
}

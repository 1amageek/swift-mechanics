import TaskSpaceQualificationSupport

@main
struct TaskSpaceQualification {
    static func main() throws {
        try TaskSpaceQualificationCases.serialPriority()
        print("TaskSpace serial priority and original Newton/Euler power witness passed")
        try TaskSpaceQualificationCases.weightedScaledAxes()
        print("TaskSpace weighted normalized SI axes witness passed")
        try TaskSpaceQualificationCases.hingeBiasAndGravity()
        print("TaskSpace hinge point bias, gravity compensation and torque power witness passed")
        try TaskSpaceQualificationCases.additionalWrenchPower()
        print("TaskSpace additional wrench and motion dual power witness passed")
        try TaskSpaceQualificationCases.rankDampingAndGates()
        print("TaskSpace rank and explicit damping error/leak gates witness passed")
        try TaskSpaceQualificationCases.sourceDomainShapeRefusals()
        print("TaskSpace source, domain and shape typed refusal witness passed")
        try TaskSpaceQualificationCases.exactWorkAndCancellation()
        print("TaskSpace exact cumulative bounds and supplied cancellation witness passed")
        try TaskSpaceQualificationCases.supplierFailureLedger()
        print("TaskSpace original supplier failure and consumed work ledger witness passed")
        print("TaskSpace eight selected synchronous public cases completed")
    }
}

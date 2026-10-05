import SwiftMechanics
#if canImport(TaskSpaceQualificationSupport)
import TaskSpaceQualificationSupport
#endif
import Testing

@Suite struct TaskSpaceQualificationTests {
    @Test func serialDynamicPriority() throws { try TaskSpaceQualificationCases.serialPriority() }
    @Test func weightedScaledPhysicalAxes() throws { try TaskSpaceQualificationCases.weightedScaledAxes() }
    @Test func originalHingeBiasAndGravity() throws { try TaskSpaceQualificationCases.hingeBiasAndGravity() }
    @Test func additionalBodyOriginWrenchAndPower() throws { try TaskSpaceQualificationCases.additionalWrenchPower() }
    @Test func strictRankAndDampedErrorGates() throws { try TaskSpaceQualificationCases.rankDampingAndGates() }
    @Test func sourceDomainAndShapeRefusals() throws { try TaskSpaceQualificationCases.sourceDomainShapeRefusals() }
    @Test func exactCumulativeWorkAndCancellation() throws { try TaskSpaceQualificationCases.exactWorkAndCancellation() }
    @Test func originalSupplierFailureLedger() throws { try TaskSpaceQualificationCases.supplierFailureLedger() }
    @Test(.timeLimit(.minutes(1))) func cancelledTaskPublishesNoCommand() async throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0], velocity: [2]), policy = try fixture.policy()
        let request = fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [4], weights: [1])))
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try TaskSpaceQualificationCases.actualTaskCancellation(request, policy: policy)
        }
        try await task.value
    }
}

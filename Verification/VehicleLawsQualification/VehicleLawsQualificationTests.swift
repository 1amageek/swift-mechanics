import SwiftMechanics
#if canImport(VehicleLawsQualificationSupport)
import VehicleLawsQualificationSupport
#endif
import Testing

@Suite struct VehicleLawsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func tireCurvesAndCombinedCapacity() throws { try VehicleLawQualificationCases.tireCurvesAndCombinedBound() }
    @Test(.timeLimit(.minutes(1))) func tireFramesMovingRoadAndPhysicalWork() throws { try VehicleLawQualificationCases.tireFramesMovingRoadAndWork() }
    @Test(.timeLimit(.minutes(1))) func tireTypedRefusalsAndActualBudgets() throws { try VehicleLawQualificationCases.tireRefusalsAndBudgets() }
    @Test(.timeLimit(.minutes(1))) func terrainClippingNormalWorkAndIrreversibleHistory() throws { try VehicleLawQualificationCases.terrainClippingCompactionAndReload() }
    @Test(.timeLimit(.minutes(1))) func terrainJanosiIntegralTravelAndPartition() throws { try VehicleLawQualificationCases.terrainJanosiTravelAndPartition() }
    @Test(.timeLimit(.minutes(1))) func terrainFrameMomentAndOriginalInterfaceWork() throws { try VehicleLawQualificationCases.terrainFramesAndInterfaceWork() }
    @Test(.timeLimit(.minutes(1))) func terrainTypedFailureCheckpointAndWorkPrefix() throws { try VehicleLawQualificationCases.terrainRefusalsCheckpointAndBudgets() }
}

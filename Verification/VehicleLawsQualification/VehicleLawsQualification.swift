import VehicleLawsQualificationSupport

@main
struct VehicleLawsQualification {
    static func main() throws {
        try VehicleLawQualificationCases.tireCurvesAndCombinedBound()
        print("Tire literal curves, stiffness, signed slips and combined capacity passed")
        try VehicleLawQualificationCases.tireFramesMovingRoadAndWork()
        print("Tire original frame, action/reaction and wheel/road/slip/rolling work passed")
        try VehicleLawQualificationCases.tireRefusalsAndBudgets()
        print("Tire explicit domain/provenance/geometry/cancellation and actual work-prefix failures passed")
        try VehicleLawQualificationCases.terrainClippingCompactionAndReload()
        print("Terrain exact clipped area, normal integrals, compaction and elastic unload/reload passed")
        try VehicleLawQualificationCases.terrainJanosiTravelAndPartition()
        print("Terrain independent Janosi integrals, small/reversed travel and interval partition passed")
        try VehicleLawQualificationCases.terrainFramesAndInterfaceWork()
        print("Terrain original rotated force/moment, reaction and moving-interface work passed")
        try VehicleLawQualificationCases.terrainRefusalsCheckpointAndBudgets()
        print("Terrain checkpoint/replay, failed-trial isolation, typed refusal and actual budget prefix passed")
    }
}

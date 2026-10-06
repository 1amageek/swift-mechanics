public protocol TireRoadEvaluating: Sendable {
    func evaluate(sample: TireRoadSample, frame: TireRoadFrame, calibration: TireBrushCalibration,
                  policy: TireAcceptancePolicy, work: inout LoadWork) throws(TireLawError) -> TireRoadResponse
}

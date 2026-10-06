import SwiftMechanics

public enum VehicleLawQualificationFixtures {
    public static func reference(_ kind: EntityKind, _ key: String, revision: UInt64 = 1) throws -> ModelReference {
        ModelReference(id:try EntityID(kind:kind,key:key),revision:revision)
    }
    public static func work(limit: Int = 100000, scalars: Int = 4096, cancelled: @escaping @Sendable () -> Bool = { false }) throws -> LoadWork {
        LoadWork(budget:try LoadBudget(maximumWork:limit,maximumScalars:scalars,isCancelled:cancelled))
    }
    public static func tireCalibration() throws -> TireBrushCalibration {
        try TireBrushCalibration(source:"synthetic-qualification-radial-brush",revision:7,
            tire:reference(.body,"fixture-tire"),roadSurface:reference(.material,"fixture-road"),
            longitudinalStiffness:3000,lateralStiffness:3000,frictionCoefficient:0.5,rollingResistanceLength:0.01,
            domain:TireCalibrationDomain(minimumNormalLoad:500,maximumNormalLoad:2000,minimumRadius:0.25,maximumRadius:0.75,
                minimumAbsoluteLongitudinalSpeed:0.1,maximumAbsoluteLongitudinalSpeed:30,maximumAbsoluteLateralSpeed:10,
                maximumAbsoluteSpin:100,maximumAbsoluteSlipRatio:2,maximumAbsoluteLateralSlipTangent:1),
            fittedFormulation:TireBrushCalibration.formulation)
    }
    public static func tirePolicy() throws -> TireAcceptancePolicy {
        try TireAcceptancePolicy(contactDistanceTolerance:1e-10,normalSpeedTolerance:1e-10,absolutePowerTolerance:1e-8,
            referencePower:1,absoluteForceTolerance:1e-8,referenceForce:1,relativeTolerance:1e-11)
    }
    public static func tireSample(vx: Double = 10, vy: Double = 0, spin: Double = 20, roadVelocity: Vector3 = .zero,
                                  rotation: UnitQuaternion = .identity, origin: Vector3 = .zero,
                                  revision: UInt64 = 7, height: Double = 0.5, normalLoad: Double = 1000,
                                  frame: ModelReference? = nil) throws -> TireRoadSample {
        let relative=try rotation.rotating(Vector3(vx,vy,0))
        return try TireRoadSample(tire:reference(.body,"fixture-tire"),roadSurface:reference(.material,"fixture-road"),
            referenceFrame:frame ?? reference(.frame,"fixture-world"),calibrationRevision:revision,timeSeconds:2,
            centerPosition:origin.adding(rotation.rotating(Vector3(0,0,height))),centerVelocity:relative.adding(roadVelocity),
            roadContactVelocity:roadVelocity,spin:spin,radius:0.5,normalLoad:normalLoad)
    }
    public static func tireFrame(rotation: UnitQuaternion = .identity, origin: Vector3 = .zero) throws -> TireRoadFrame {
        try TireRoadFrame(reference:reference(.frame,"fixture-world"),contactToReference:rotation,planePoint:origin)
    }
    public static func soil(n: Double = 1, revision: UInt64 = 9, unloading: Double = 10000) throws -> TerrainSoilCalibration {
        try TerrainSoilCalibration(source:"synthetic-qualification-bekker-janosi",revision:revision,
            material:reference(.material,"fixture-soil"),cohesiveModulus:1000,frictionalModulus:1000,
            sinkageExponent:n,unloadingModulus:unloading,cohesion:10,frictionTangent:0.5,janosiLength:0.2,
            domain:TerrainCalibrationDomain(minimumFootprintWidth:0.5,maximumFootprintWidth:2,maximumSinkage:0.5,
                maximumShearTravel:10,maximumPressure:2000,maximumNormalLoad:10000,maximumTangentialSpeed:2,
                maximumNormalSpeed:1,minimumTimeStep:1e-6,maximumTimeStep:2),fittedFormulation:TerrainSoilCalibration.formulation)
    }
    public static func terrainPolicy() throws -> TerrainAcceptancePolicy {
        try TerrainAcceptancePolicy(absoluteEnergyTolerance:1e-9,referenceEnergy:1,absolutePressureTolerance:1e-8,
            referencePressure:1,absoluteAreaTolerance:1e-12,relativeTolerance:1e-11)
    }
    public static func footprint() throws -> TerrainRectangularFootprint {
        try TerrainRectangularFootprint(minimumX:0.25,maximumX:1.75,minimumY:0.5,maximumY:1.5)
    }
    public static func grid(work: inout LoadWork, rotation: UnitQuaternion = .identity, origin: Vector3 = .zero,
                            revision: UInt64 = 3, maximumCells: Int = 4) throws -> TerrainGrid {
        try TerrainGrid(source:"synthetic-qualification-grid",revision:revision,terrainBody:reference(.body,"fixture-terrain"),
            material:reference(.material,"fixture-soil"),referenceFrame:reference(.frame,"fixture-world"),
            terrainToReference:rotation,referenceOrigin:origin,minimumX:0,minimumY:0,cellWidth:1,cellLength:1,
            columns:2,rows:2,undeformedHeights:[0,0,0,0],maximumCells:maximumCells,work:&work)
    }
    public static func history(service: any TerrainLawEvaluating, work: inout LoadWork, n: Double = 1,
                               rotation: UnitQuaternion = .identity, origin: Vector3 = .zero) throws -> TerrainPatchHistory {
        let grid=try grid(work:&work,rotation:rotation,origin:origin)
        return try service.initialHistory(grid:grid,calibration:soil(n:n),footprint:footprint(),
            interfaceBody:reference(.body,"fixture-interface"),interfaceHeight:0,timeSeconds:0,policy:terrainPolicy(),work:&work)
    }
    public static func step(_ history: TerrainPatchHistory, localVelocity: Vector3, dt: Double = 1,
                            terrainVelocity: Vector3 = .zero, referencePoint: Vector3 = .zero,
                            footprint: TerrainRectangularFootprint? = nil, startTime: Double? = nil,
                            gridRevision: UInt64? = nil) throws -> TerrainContactStep {
        try TerrainContactStep(interfaceBody:history.interfaceBody,terrainBody:history.grid.terrainBody,
            referenceFrame:history.grid.referenceFrame,gridRevision:gridRevision ?? history.grid.revision,
            calibrationRevision:history.calibration.revision,footprint:footprint ?? history.footprint,
            startTimeSeconds:startTime ?? history.timeSeconds,timeStepSeconds:dt,
            interfaceVelocity:history.grid.terrainToReference.rotating(localVelocity).adding(terrainVelocity),
            terrainVelocity:terrainVelocity,wrenchReferencePoint:referencePoint)
    }
}

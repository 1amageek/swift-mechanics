import SwiftMechanics

public struct HydroelasticQualificationCases: HydroelasticQualifying {
    private typealias F = HydroelasticQualificationFixtures
    public init() {}

    public func run(_ selected: HydroelasticQualificationCase) throws(HydroelasticQualificationError) {
        switch selected {
        case .rigidTriangle: try rigidTriangle()
        case .rigidQuadrilateral: try rigidQuadrilateral()
        case .twoFieldsReciprocal: try twoFieldsReciprocal()
        case .currentGeometryAndCovariance: try currentGeometryAndCovariance()
        case .domainsAndStaleness: try domainsAndStaleness()
        case .budgetsAndCancellation:
            guard #available(macOS 15.0, *) else { throw .unsupportedOperatingSystem }
            try budgetsAndCancellation()
        }
    }

    private func rigidTriangle() throws(HydroelasticQualificationError) {
        let first=try F.cell("soft-a"), plane=try F.plane(first), origin=try F.vector(0.4,-0.2,0.7)
        let result=try F.solve(first,.rigidPlane(plane),origin:origin)
        let integral=584.0/375, xp=32.0/75, yp=832.0/1875
        try F.require(result.triangles.count == 1,"Triangle section has one actual triangle")
        try F.polygon(result,[F.vector(0,0,0.2),F.vector(0.8,0,0.2),F.vector(0,0.8,0.2)])
        try F.near(result.area,8.0/25,"Analytic triangle area"); try F.near(result.integratedPressure,integral,"Analytic pressure integral")
        guard let normal=result.normal else { throw .assertion("Physical normal missing") }
        try F.near(normal,.unitZ,"Supplied rigid normal")
        try F.near(result.wrenchOnSecond.force,F.vector(0,0,integral),"Rigid resultant")
        try F.near(result.wrenchOnSecond.torque,F.vector(yp-origin.y*integral,origin.x*integral-xp,0),"Original world moment")
        try opposite(result)
        let weights=[704.0/1875,800.0/1875,832.0/1875,584.0/1875]
        for i in 0..<4 { try F.near(result.firstNodalForces[i],F.vector(0,0,-weights[i]),"Original analytic A nodal load") }
        try F.near(result.firstPower,-7136.0/1875,"Original prescribed first power")
        try F.near(result.secondPower,3168.0/1875,"Original prescribed rigid power")
        try F.near(result.totalPower,-3968.0/1875,"Original total supplied-pressure power")
        try F.nodal(result.firstNodalForces,first.representation.state,origin:origin,wrench:result.wrenchOnFirst,power:result.firstPower)
        try rigidPower(result,plane)
        try F.require(result.secondNodalForces == nil,"Rigid partner has no fictitious nodal layout")
        try F.require(result.first.sample == first.sample && result.first.sampleTimeSeconds == 0.5 && result.frame == first.representation.mesh.mesh.frame,"Original sample/frame retained")
        try F.require(result.first.expectedMeshSource == first.expectedMeshSource && result.first.expectedCellSource == first.expectedCellSource && result.first.calibration.source == first.calibration.source,"Original physical and calibration sources retained")
        try F.require(result.first.representation.field?.pressurePascals == [2,5,6,7],"Actual supplied pressure field retained")
        try F.near(result.first.calibration.declaredPressureApproximationPascals,0.25,"Attributable pressure approximation")
        try F.near(result.first.calibration.declaredGeometryApproximationMeters,0.0001,"Attributable geometry approximation")
        try F.require(result.first.calibration.materialSource == first.representation.mesh.mesh.materials[0].source,"Original material source retained")
        try F.residuals(result)
    }

    private func rigidQuadrilateral() throws(HydroelasticQualificationError) {
        let vertices=try [F.vector(-1,0,0),F.vector(1,0,0),F.vector(0,1,1),F.vector(0,-1,1)]
        let first=try F.cell("square-a",vertices:vertices,pressure:{5+2*$0.x+3*$0.y+$0.z})
        let plane=try F.plane(first,point:F.vector(0,0,0.5),linear:F.vector(0,0,0.5))
        let result=try F.solve(first,.rigidPlane(plane))
        try F.require(result.triangles.count == 2,"Actual quadrilateral fan has two triangles")
        try F.polygon(result,[F.vector(-0.5,-0.5,0.5),F.vector(0.5,-0.5,0.5),F.vector(0.5,0.5,0.5),F.vector(-0.5,0.5,0.5)])
        try F.near(result.area,1,"Independent square area"); try F.near(result.integratedPressure,5.5,"Independent square affine pressure")
        try F.near(result.wrenchOnSecond.torque,F.vector(0.25,-1.0/6,0),"Independent square pressure moment")
        let weights=[31.0/24,35.0/24,1.5,1.25]
        for i in 0..<4 { try F.near(result.firstNodalForces[i],F.vector(0,0,-weights[i]),"Independent square shape-pressure integral") }
        try F.near(result.firstPower,-173.0/12,"Independent square first power"); try F.near(result.secondPower,3,"Independent square rigid power")
        try F.nodal(result.firstNodalForces,first.representation.state,origin:.zero,wrench:result.wrenchOnFirst,power:result.firstPower)
        let reversePlane=try F.plane(first,point:plane.representation.point,normal:F.vector(0,0,-1),linear:plane.representation.velocityAboutPoint.linear)
        let reverse=try F.solve(first,.rigidPlane(reversePlane))
        try F.near(reverse.wrenchOnSecond.force,result.wrenchOnFirst.force,"Normal reversal force")
        try F.near(reverse.wrenchOnSecond.torque,result.wrenchOnFirst.torque,"Normal reversal moment")
        try F.near(reverse.firstPower,-result.firstPower,"Normal reversal physical power")
        try opposite(result); try rigidPower(result,plane); try F.residuals(result)
    }

    private func twoFieldsReciprocal() throws(HydroelasticQualificationError) {
        let a=try F.cell("soft-a")
        let b=try F.cell("soft-b",vertices:F.shiftedVertices(-0.1,-0.1,-0.1),pressure:{1.6+3*$0.x+4*$0.y+7*$0.z},velocity:{-0.2+2*$0.x-$0.y+$0.z})
        let result=try F.solve(a,.field(b)), reverse=try F.solve(b,.field(a))
        try F.near(result.area,1.0/8,"Two-field original clipped area"); try F.near(result.integratedPressure,25.0/48,"Two-field original pressure integral")
        try F.polygon(result,[F.vector(0,0,0.2),F.vector(0.5,0,0.2),F.vector(0,0.5,0.2)])
        try F.polygon(reverse,[F.vector(0,0,0.2),F.vector(0.5,0,0.2),F.vector(0,0.5,0.2)])
        guard let normal=result.normal,let reverseNormal=reverse.normal,let second=result.secondNodalForces,let reverseSecond=reverse.secondNodalForces else { throw .assertion("Actual two-field normal/layout missing") }
        try F.near(normal,.unitZ,"Original grad(pB-pA) normal"); try F.near(reverseNormal,F.vector(0,0,-1),"Reciprocal pressure normal")
        let weightsA=[91.0/384,34.0/384,35.0/384,40.0/384], weightsB=[31.0/384,54.0/384,55.0/384,60.0/384]
        for i in 0..<4 {
            try F.near(result.firstNodalForces[i],F.vector(0,0,-weightsA[i]),"Independent clipped A nodal weight")
            try F.near(second[i],F.vector(0,0,weightsB[i]),"Independent clipped B nodal weight")
            try F.near(reverse.firstNodalForces[i],second[i],"Body-order B load covariance")
            try F.near(reverseSecond[i],result.firstNodalForces[i],"Body-order A load covariance")
        }
        try F.near(result.wrenchOnSecond.force,F.vector(0,0,25.0/48),"Original two-field force")
        try F.near(result.wrenchOnSecond.torque,F.vector(35.0/384,-17.0/192,0),"Original two-field moment")
        try F.near(result.firstPower,-53.0/48,"Original clipped A power"); try F.near(result.secondPower,11.0/128,"Original clipped B power")
        try F.near(result.totalPower,-391.0/384,"Original supplied two-field total power")
        try F.near(reverse.area,result.area,"Reciprocal area"); try F.near(reverse.integratedPressure,result.integratedPressure,"Reciprocal pressure")
        try F.near(reverse.wrenchOnFirst.force,result.wrenchOnSecond.force,"Reciprocal body force"); try F.near(reverse.wrenchOnFirst.torque,result.wrenchOnSecond.torque,"Reciprocal body moment")
        try F.near(reverse.firstPower,result.secondPower,"Reciprocal B power"); try F.near(reverse.secondPower,result.firstPower,"Reciprocal A power")
        for triangle in result.triangles {
            for point in [triangle.first,triangle.second,triangle.third] {
                try F.near(point.z,0.2,"Independent equal-pressure plane")
                try F.near(2+3*point.x+4*point.y+5*point.z,1.6+3*point.x+4*point.y+7*point.z,"Original physical pressures equal")
                try F.require(point.x >= -1e-10 && point.y >= -1e-10 && point.x+point.y <= 0.5+1e-10,"Independent intersection domain")
            }
        }
        try F.nodal(result.firstNodalForces,a.representation.state,origin:.zero,wrench:result.wrenchOnFirst,power:result.firstPower)
        try F.nodal(second,b.representation.state,origin:.zero,wrench:result.wrenchOnSecond,power:result.secondPower)
        try opposite(result); try F.residuals(result); try F.residuals(reverse)
    }

    private func currentGeometryAndCovariance() throws(HydroelasticQualificationError) {
        let stretched=try F.cell("stretched",current:[.zero,F.vector(2,0,0),.unitY,.unitZ])
        let stretchResult=try F.solve(stretched,.rigidPlane(F.plane(stretched)))
        try F.polygon(stretchResult,[F.vector(0,0,0.2),F.vector(1.6,0,0.2),F.vector(0,0.8,0.2)])
        try F.near(stretchResult.area,16.0/25,"Actual current stretch area")
        try F.near(stretchResult.integratedPressure,272.0/75,"Actual current pressure reconstruction")
        try F.near(stretchResult.wrenchOnSecond.torque,F.vector(1856.0/1875,-3968.0/1875,0),"Current physical moment")
        let weights=[1600.0/1875,1984.0/1875,1856.0/1875,1360.0/1875]
        for i in 0..<4 { try F.near(stretchResult.firstNodalForces[i],F.vector(0,0,-weights[i]),"Current inverse shape weight") }
        try F.near(stretchResult.firstPower,-3712.0/375,"Current affine physical power")
        try F.near(stretchResult.secondPower,2432.0/625,"Current rigid physical power")
        try F.require(stretched.representation.mesh.mesh.nodes[1].referencePosition == .unitX,"Reference geometry not silently deformed")
        let first=try F.cell("soft-a"), plane=try F.plane(first), baseline=try F.solve(first,.rigidPlane(plane))
        let old=first.representation.state
        var positions: [Vector3]=[], velocities: [Vector3]=[]
        for i in old.positions.indices { positions.append(try F.move(old.positions[i])); velocities.append(try F.rotate(old.velocities[i])) }
        let state=NodalState(frame:old.frame,meshRevision:old.meshRevision,nodeIdentifiers:old.nodeIdentifiers,positions:positions,velocities:velocities)
        let changed=try F.selection(first,body:F.body(first,state:state))
        let movedPlane=try F.plane(changed,point:F.move(plane.representation.point),normal:F.rotate(plane.representation.normal),
            linear:F.rotate(plane.representation.velocityAboutPoint.linear),angular:F.rotate(plane.representation.velocityAboutPoint.angular))
        let origin=try F.vector(2,-1,0.5), result=try F.solve(changed,.rigidPlane(movedPlane),origin:origin)
        try F.polygon(result,[F.move(F.vector(0,0,0.2)),F.move(F.vector(0.8,0,0.2)),F.move(F.vector(0,0.8,0.2))])
        try F.near(result.area,baseline.area,"Rigid coordinate covariance area"); try F.near(result.integratedPressure,baseline.integratedPressure,"Rigid coordinate covariance pressure")
        try F.near(result.wrenchOnSecond.force,F.rotate(baseline.wrenchOnSecond.force),"Force coordinate covariance")
        try F.near(result.wrenchOnSecond.torque,F.rotate(baseline.wrenchOnSecond.torque),"Moment coordinate covariance")
        for i in 0..<4 { try F.near(result.firstNodalForces[i],F.rotate(baseline.firstNodalForces[i]),"Nodal coordinate covariance") }
        try F.near(result.firstPower,baseline.firstPower,"First power scalar covariance"); try F.near(result.secondPower,baseline.secondPower,"Rigid power scalar covariance")
        try F.nodal(result.firstNodalForces,state,origin:origin,wrench:result.wrenchOnFirst,power:result.firstPower)
        try rigidPower(result,movedPlane)
        let world=try F.solve(changed,.rigidPlane(movedPlane))
        let transport=try F.cross(origin,result.wrenchOnSecond.force)
        let expected=try F.vector(result.wrenchOnSecond.torque.x+transport.x,result.wrenchOnSecond.torque.y+transport.y,result.wrenchOnSecond.torque.z+transport.z)
        try F.near(world.wrenchOnSecond.torque,expected,"Original world/body-origin wrench transport")
        try F.near(world.secondPower,result.secondPower,"Rigid power invariant under wrench origin transport")
        try F.residuals(stretchResult); try F.residuals(result); try F.residuals(world)
    }

    private func domainsAndStaleness() throws(HydroelasticQualificationError) {
        let first=try F.cell("soft-a"), plane=try F.plane(first), policy=try F.policy()
        let service: any HydroelasticPatchConstructing=ReferenceHydroelasticPatchConstructor()
        func refused(_ selected: HydroelasticCellSelection,_ partner: HydroelasticPartner,_ failure: F.Failure) throws(HydroelasticQualificationError) {
            var work=try F.work()
            try F.expect(failure) { () throws(HydroelasticError) in _=try service.construct(selected,against:partner,origin:.zero,policy:policy,work:&work) }
        }
        let farPlane=try F.plane(first,point:F.vector(0,0,2)), absent=try F.solve(first,.rigidPlane(farPlane))
        try empty(absent)
        let far=try F.cell("far",vertices:F.shiftedVertices(3,3,0),pressure:{1.6+3*$0.x+4*$0.y+7*$0.z})
        try empty(F.solve(first,.field(far)))
        let constantA=try F.cell("constant-a",pressure:{_ in 5}),constantB=try F.cell("constant-b",pressure:{_ in 6})
        let parallel=try F.solve(constantA,.field(constantB)); try empty(parallel)
        try F.require(parallel.normal == nil,"Separated constant pressures do not invent a normal")
        let equal=try F.cell("constant-equal",pressure:{_ in 5})
        try refused(constantA,.field(equal),.ambiguous)
        try refused(first,.rigidPlane(F.plane(first,point:.zero)),.boundary)
        let inverted=try F.cell("inverted",current:[.zero,F.vector(-1,0,0),.unitY,.unitZ],pressure:{_ in 5})
        try refused(inverted,.rigidPlane(F.plane(inverted)),.inverted)
        let negative=try F.cell("negative",pressure:{_ in -1}), nonfinite=try F.cell("nonfinite",pressure:{_ in .nan})
        try refused(negative,.rigidPlane(plane),.invalid); try refused(nonfinite,.rigidPlane(plane),.invalid)
        try refused(F.selection(first,body:F.body(first,missing:true)),.rigidPlane(plane),.missingField)
        try refused(F.selection(first,cell:999),.rigidPlane(plane),.missingCell)
        let otherSource=try F.source("stale",99)
        for selected in [try F.selection(first,model:99),try F.selection(first,meshRevision:99),try F.selection(first,pressureRevision:99),
                         try F.selection(first,meshSource:otherSource),try F.selection(first,cellSource:otherSource),try F.selection(first,calibrationSource:otherSource)] {
            try refused(selected,.rigidPlane(plane),.stale)
        }
        for field in [try F.field(first,revision:99),try F.field(first,meshRevision:99),try F.field(first,source:otherSource)] {
            try refused(F.selection(first,body:F.body(first,field:field)),.rigidPlane(plane),.stale)
        }
        let otherFrame=try F.identity(.frame,"other"),otherMaterial=try F.identity(.material,"other")
        try refused(F.selection(first,body:F.body(first,field:F.field(first,frame:otherFrame))),.rigidPlane(plane),.frame)
        try refused(F.selection(first,body:F.body(first,field:F.field(first,materials:[otherMaterial]))),.rigidPlane(plane),.material)
        try refused(F.selection(first,body:F.body(first,field:F.field(first,ids:[10,11,12]))),.rigidPlane(plane),.layout)
        try refused(F.selection(first,body:F.body(first,field:F.field(first,ids:[11,10,12,13]))),.rigidPlane(plane),.layout)
        let old=first.representation.state
        let badState=NodalState(frame:old.frame,meshRevision:old.meshRevision,nodeIdentifiers:[11,10,12,13],positions:old.positions,velocities:old.velocities)
        try refused(F.selection(first,body:F.body(first,state:badState)),.rigidPlane(plane),.layout)
        let calibration=first.calibration
        let wrongMaterial=try F.producer { () throws(HydroelasticError) in
            try HydroelasticCalibration(source:calibration.source,material:otherMaterial,materialSource:calibration.materialSource,
                declaredPressureApproximationPascals:0,declaredGeometryApproximationMeters:0)
        }
        try refused(F.selection(first,calibration:wrongMaterial),.rigidPlane(plane),.material)
        let other=try F.cell("soft-b")
        try refused(first,.field(F.selection(other,time:0.6)),.sample)
        try refused(first,.field(F.selection(other,sample:otherSource)),.sample)
        try refused(first,.field(F.selection(other,model:8)),.stale)
        for mode in 0..<4 {
            let representation=plane.representation
            let changed=try F.producer { () throws(HydroelasticError) in
                try HydroelasticPlaneSelection(representation:representation,expectedModelRevision:9,expectedPlaneRevision:mode == 0 ? 99 : 4,
                    geometrySource:plane.geometrySource,expectedGeometrySource:mode == 1 ? otherSource : plane.expectedGeometrySource,
                    sample:mode == 2 ? otherSource : plane.sample,sampleTimeSeconds:mode == 3 ? 0.6 : plane.sampleTimeSeconds)
            }
            try refused(first,.rigidPlane(changed),mode < 2 ? .stale : .sample)
        }
        try refused(first,.wholeMeshDiscovery,.wholeMesh); try refused(first,.arbitrarySurface,.surface); try refused(first,.evolution,.evolution)
    }

    @available(macOS 15.0, *)
    private func budgetsAndCancellation() throws(HydroelasticQualificationError) {
        let first=try F.cell("soft-a"),plane=try F.plane(first),service: any HydroelasticPatchConstructing=ReferenceHydroelasticPatchConstructor()
        let baseline=try F.solve(first,.rigidPlane(plane)),required=baseline.work.operations
        var exact=try F.work(storage:1104,operations:required)
        let policy=try F.policy()
        let result=try F.producer { () throws(HydroelasticError) in try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:policy,work:&exact) }
        try F.near(result.integratedPressure,baseline.integratedPressure,"Exact original work budget retains behavior")
        try F.require(exact.operations == required && exact.peakScalarStorage == 1104,"Actual exact operation/storage boundary")
        for mode in 0..<2 {
            var work=try F.work(storage:mode == 0 ? 1103 : 1104,operations:mode == 0 ? required : required-1)
            let failure: F.Failure=mode == 0 ? .storage(1103) : .operations(required-1)
            try F.expect(failure) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:policy,work:&work) }
            if mode == 1 { try F.require(work.operations > 0,"Rejected query retains consumed work") }
        }
        for restricted in [try F.policy(nodes:3),try F.policy(metadata:1),try F.policy(vertices:2)] {
            var work=try F.work()
            try F.expect(.capacity) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:restricted,work:&work) }
        }
        let square=try F.cell("square",vertices:[F.vector(-1,0,0),F.vector(1,0,0),F.vector(0,1,1),F.vector(0,-1,1)],pressure:{5+2*$0.x+3*$0.y+$0.z})
        let squarePlane=try F.plane(square,point:F.vector(0,0,0.5)),trianglePolicy=try F.policy(triangles:1)
        var triangleWork=try F.work()
        try F.expect(.capacity) { () throws(HydroelasticError) in _=try service.construct(square,against:.rigidPlane(squarePlane),origin:.zero,policy:trianglePolicy,work:&triangleWork) }
        let pressurePolicy=try F.policy(pressure:6)
        var pressureWork=try F.work()
        try F.expect(.invalid) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:pressurePolicy,work:&pressureWork) }
        let longSource=try F.source(String(repeating:"p",count:1024)),long=try F.selection(first,meshSource:longSource)
        var metadataWork=try F.work()
        try F.expect(.capacity) { () throws(HydroelasticError) in _=try service.construct(long,against:.rigidPlane(plane),origin:.zero,policy:policy,work:&metadataWork) }
        let counter=HydroelasticCancellationCounter(),countPolicy=try F.policy(cancelled:{counter.check()})
        var counted=try F.work()
        _=try F.producer { () throws(HydroelasticError) in try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:countPolicy,work:&counted) }
        try F.require(counter.count > 100,"Actual bounded cancellation checkpoints observed")
        let late=HydroelasticCancellationCounter(cancelAt:counter.count),latePolicy=try F.policy(cancelled:{late.check()})
        var cancelled=try F.work()
        try F.expect(.cancelled) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:latePolicy,work:&cancelled) }
        try F.require(late.count == counter.count && cancelled.operations == counted.operations && cancelled.operations == required,"Late cancellation after all physical work, before publication")
        let immediate=try F.policy(cancelled:{true})
        var early=try F.work()
        try F.expect(.cancelled) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:immediate,work:&early) }
        try F.require(early.operations == 0 && early.peakScalarStorage == 0,"Early cancellation before allocation/arithmetic")
        try F.expect(.invalid) { () throws(HydroelasticError) in
            _=try HydroelasticPolicy(maximumNodes:0,maximumCells:1,maximumMaterials:1,maximumMetadataBytes:1,maximumVertices:1,maximumTriangles:1,
                maximumPressure:1,minimumVolumeRatio:1e-10,inverseRelativeTolerance:1e-12,minimumTriangleArea:1e-12,distanceTolerance:1e-9,
                barycentricTolerance:1e-10,normalTolerance:1e-10,pressureTolerance:1e-9,gradientTolerance:1e-12,forceScale:1,momentScale:1,powerScale:1,residualTolerance:1e-8)
        }
        let calibration=first.calibration
        try F.expect(.invalid) { () throws(HydroelasticError) in
            _=try HydroelasticCalibration(source:calibration.source,material:calibration.material,materialSource:calibration.materialSource,
                declaredPressureApproximationPascals:.nan,declaredGeometryApproximationMeters:0)
        }
        try F.expect(.invalid) { () throws(HydroelasticError) in
            _=try HydroelasticCellSelection(representation:first.representation,cellIdentifier:50,expectedModelRevision:9,expectedMeshRevision:1,expectedPressureRevision:3,
                expectedMeshSource:first.expectedMeshSource,expectedCellSource:first.expectedCellSource,calibration:calibration,
                expectedCalibrationSource:first.expectedCalibrationSource,sample:first.sample,sampleTimeSeconds:.infinity)
        }
    }

    public func taskCancellationEntry() throws(HydroelasticQualificationError) -> @Sendable () throws(HydroelasticQualificationError) -> Void {
        let first=try F.cell("soft-a"),plane=try F.plane(first),policy=try F.policy()
        return { () throws(HydroelasticQualificationError) in
            let service: any HydroelasticPatchConstructing=ReferenceHydroelasticPatchConstructor()
            var work=try F.work()
            try F.expect(.cancelled) { () throws(HydroelasticError) in _=try service.construct(first,against:.rigidPlane(plane),origin:.zero,policy:policy,work:&work) }
            try F.require(work.operations == 0 && work.peakScalarStorage == 0,"Actual Task cancellation before publication/work")
        }
    }

    private func opposite(_ result: HydroelasticPatch) throws(HydroelasticQualificationError) {
        try F.near(F.sum([result.wrenchOnFirst.force,result.wrenchOnSecond.force]),.zero,"Original wrench action/reaction")
        try F.near(F.sum([result.wrenchOnFirst.torque,result.wrenchOnSecond.torque]),.zero,"Original moment action/reaction")
    }
    private func rigidPower(_ result: HydroelasticPatch,_ plane: HydroelasticPlaneSelection) throws(HydroelasticQualificationError) {
        let lever=try F.subtract(plane.representation.point,result.origin),transport=try F.cross(lever,result.wrenchOnSecond.force)
        let pointMoment=try F.subtract(result.wrenchOnSecond.torque,transport)
        let power=F.dot(result.wrenchOnSecond.force,plane.representation.velocityAboutPoint.linear)+F.dot(pointMoment,plane.representation.velocityAboutPoint.angular)
        try F.near(power,result.secondPower,"Supplied rigid body-point/world-wrench virtual power")
    }
    private func empty(_ result: HydroelasticPatch) throws(HydroelasticQualificationError) {
        try F.require(result.triangles.isEmpty && result.area == 0 && result.integratedPressure == 0,"Physically absent patch")
        try F.require(result.wrenchOnFirst.force == .zero && result.wrenchOnSecond.force == .zero && result.wrenchOnFirst.torque == .zero && result.wrenchOnSecond.torque == .zero,"Absent original wrench")
        try F.require(result.firstPower == 0 && result.secondPower == 0 && result.totalPower == 0,"Absent original power")
        for force in result.firstNodalForces { try F.require(force == .zero,"Absent nodal load") }
        if let second=result.secondNodalForces { for force in second { try F.require(force == .zero,"Absent second nodal load") } }
        try F.residuals(result)
    }
}

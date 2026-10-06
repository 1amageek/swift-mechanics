import SwiftMechanics

public enum MJCFQualificationCases {
    public static func check(_ condition: Bool, _ message: String) throws(MJCFQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    public static func near(_ actual: Double, _ expected: Double, _ message: String) throws(MJCFQualificationError) {
        try check(actual.isFinite && abs(actual - expected) <= 1e-9 * max(1,abs(expected)), message)
    }
    static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ message: String) throws(MJCFQualificationError) {
        try near(actual.x,x,message + " x"); try near(actual.y,y,message + " y"); try near(actual.z,z,message + " z")
    }
    static func body(_ model: MJCFImportedModel, _ name: String) throws(MJCFQualificationError) -> MJCFEntityBinding {
        for b in model.bodies { if b.originalName == name { return b } }; throw .assertion("Original body identity missing")
    }
    static func sample(_ model: MJCFImportedModel, q: Double, v: Double, controls: [Double], time: Double = 1) throws(MJCFQualificationError) -> MJCFModelSample {
        var work = MJCFWork(policy: try MJCFQualificationFixtures.policy()), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        let state = try MJCFQualificationFixtures.translated {
            try model.compiled.makeState(KinematicState(revision: MJCFQualificationFixtures.revision, time: time, q: [q], v: [v], acceleration: [0]))
        }
        let evaluator: any MJCFModelEvaluating = MJCFQualificationFixtures.adapter()
        return try MJCFQualificationFixtures.translated {
            try evaluator.sample(model, state: state, controls: controls, tolerance: MJCFQualificationFixtures.tolerance(), work: &work, actuationWork: &actuation, numericalWork: &numerical)
        }
    }
    public static func originalSlideDefaultsAndInertia() throws(MJCFQualificationError) {
        let model = try MJCFQualificationFixtures.imported(), slider = try body(model,"slider"), tip = try body(model,"tip")
        try check(model.compiled.stamp == ModelStamp(identity: "mjcf-qualified", revision: 19), "Caller model/source revision preserved")
        try check(model.context.source.source == MJCFQualificationFixtures.source && model.nativeDocument.descriptor.revision == 19, "Source identity retained")
        try check(model.joints.count == 1 && model.joints[0].binding.originalName == "j", "Original joint retained")
        try near(model.joints[0].reference,2,"Original slide ref in metres")
        guard let axis = model.joints[0].binding.effectiveAttributes.first(where: { $0.name == "axis" }) else { throw .assertion("Inherited axis missing") }
        try check(axis.inherited && axis.value == "2 0 0", "Nested class overrides main axis")
        guard case .element(let kind, let fields) = model.document.nodes[axis.definingNode].content else { throw .assertion("Default origin is not an element") }
        try check(kind == "joint" && fields.contains(where: { $0.name == "ref" && $0.value == "2" }), "Effective source is original named-class joint template")
        let initial = try MJCFQualificationFixtures.translated { try model.compiled.initialSnapshot.body(slider.entity) }
        try vector(initial.motion.pose.translation,1,2,3,"Original zero displacement body pose")
        let result = try sample(model,q:0.25,v:1.5,controls:[4])
        let moved = try MJCFQualificationFixtures.translated { try result.kinematics.body(slider.entity) }
        let fixed = try MJCFQualificationFixtures.translated { try result.kinematics.body(tip.entity) }
        try vector(moved.motion.pose.translation,1,2.25,3,"Rotated slide world position")
        try vector(fixed.motion.pose.translation,1,3.25,3,"Fixed descendant world position")
        try vector(moved.motion.velocity.linear,0,1.5,0,"Slide physical velocity")
        try vector(fixed.motion.velocity.linear,0,1.5,0,"Fixed descendant inherits motion")
        try vector(moved.motion.velocity.angular,0,0,0,"Slide has zero angular velocity")
        guard let record = model.compiled.descriptor.bodies.first(where: { $0.id == slider.entity }), case .spatial(let spatial) = record,
              let inertia = spatial.inertia else { throw .assertion("Real explicit inertia absent") }
        try near(inertia.properties.mass,2,"Original explicit mass")
        try vector(inertia.properties.centerOfMass,0.1,0.2,0.3,"Original inertial body translation")
        let tensor = inertia.properties.inertiaAtCenter
        try near(tensor.m00,3,"Rotated inertia xx"); try near(tensor.m11,2,"Rotated inertia yy"); try near(tensor.m22,4,"Rotated inertia zz")
        try near(tensor.m01,0,"Rotated inertia off diagonal")
        try check(inertia.provenance == model.context.source && inertia.quality == .exact, "Inertia original source/quality")
        guard let fixedRecord = model.compiled.descriptor.bodies.first(where: { $0.id == tip.entity }) else { throw .assertion("Fixed descendant record absent") }
        try check(fixedRecord.mode == .dynamic, "Moving ancestry preserves dynamic inertia requirement")
        try vector(model.gravity.accelerationAtOrigin,0,0,-9.81,"Original gravity SI")
    }
    public static func originalOffsetHingeAndDegreeReference() throws(MJCFQualificationError) {
        let model = try MJCFQualificationFixtures.imported(MJCFQualificationFixtures.hinge,equality:false), rotor = try body(model,"rotor")
        try near(model.joints[0].reference,Double.pi/2,"Degree ref converts to radians")
        let initial = try MJCFQualificationFixtures.translated { try model.compiled.initialSnapshot.body(rotor.entity) }
        try vector(initial.motion.pose.translation,1,0,0,"Ref is initial physical angle, native q remains zero")
        let result = try sample(model,q:Double.pi/2,v:2,controls:[])
        let moved = try MJCFQualificationFixtures.translated { try result.kinematics.body(rotor.entity) }
        try vector(moved.motion.pose.translation,1.5,-0.5,0,"Offset hinge rotates original body origin about joint point")
        let rotated = try MJCFQualificationFixtures.translated { try moved.motion.pose.rotation.rotating(.unitX) }
        try vector(rotated,0,1,0,"Hinge body orientation uses native displacement")
        try vector(moved.motion.velocity.angular,0,0,2,"Physical hinge angular velocity")
        try vector(moved.motion.velocity.linear,1,0,0,"Physical hinge origin velocity")
        try near(result.sensorValues[0],Double.pi,"Joint position sensor restores original angle ref")
        try near(result.sensorValues[1],2,"Joint velocity sensor remains radian SI")
        try check(result.sensorDimensions == [.angle,PhysicalDimension(time:-1,angle:1)], "Original hinge sensor units")
    }
    public static func originalAffinePowerSensorsAndEquality() throws(MJCFQualificationError) {
        let model = try MJCFQualificationFixtures.imported()
        guard let initial = model.initialEqualityEvaluation else { throw .assertion("Actual equality producer result absent") }
        try near(initial.values[0],-0.5,"Original q-0.25 divided by R=0.5")
        try near(initial.jacobian[0],0.4,"Original coefficient*S/R")
        try near(model.initialPhysicalEqualities[0].residualSI,-0.25,"Nonzero original initial residual retained")
        let result = try sample(model,q:0.5,v:1.5,controls:[4])
        let expected: [Double] = [2.5,1.5,7.5,4.5,5,3]
        try check(result.sensorValues.count == expected.count,"Every original sensor published")
        for i in expected.indices { try near(result.sensorValues[i],expected[i],"Original ref/coef/gear sensor witness") }
        try check(result.sensorDimensions == [.length,.velocity,.length,.velocity,.length,.velocity],"Slide/tendon/motor sensor SI units")
        try check(result.motorResponses.count == 1,"Actual original motor response")
        try near(result.motorResponses[0].efforts[0],8,"Original ctrl=4 and gear=2 gives force=8")
        try near(result.motorResponses[0].actualPower,12,"Original physical power 8*1.5")
        try near(result.motorResponses[0].virtualPower,12,"Actual qualified transpose power")
        try near(result.motorResponses[0].balanceResidual,0,"Actual qualified power residual")
        try near(result.physicalEqualities[0].residualSI,0.25,"Independent original q-0.25 SI residual")
        try near(result.physicalEqualities[0].gradientSI[0],1,"Original SI equality gradient")
        try near(result.physicalEqualities[0].originalReplayErrorSI,0,"Original/supplier SI replay")
        try check(result.source == model.context.source && result.stamp == model.compiled.stamp && result.state.state.time == 1,"Actual query source/state/time")
        try check(model.tendons[0].entity.kind == .load && model.motors[0].entity.kind == .actuator && model.sensors[0].entity.kind == .sensor,"Distinct original identity namespaces")
    }
    public static func sourceLossProvenanceAndExport() throws(MJCFQualificationError) {
        let model = try MJCFQualificationFixtures.imported()
        for loss in model.losses {
            try check(loss.source == model.context.source && loss.node >= 0 && loss.node < model.document.nodes.count && !loss.reason.isEmpty,"Loss retains original node/source/reason")
        }
        try check(model.losses.contains(where: { $0.category == .mujocoSolverExecution && $0.field == "timestep" }),"Original unapplied option loss")
        try check(model.losses.contains(where: { $0.category == .softEqualitySolver && $0.node == model.equalities[0].node }),"Original soft equality loss")
        try check(model.materials.count == 1 && model.materials[0].attributes.contains(where: { $0.name == "rgba" && $0.value == "0.1 0.2 0.3 0.4" && $0.inherited }),"Original material default preserved")
        var work = MJCFWork(policy: try MJCFQualificationFixtures.policy()), xml = try MJCFQualificationFixtures.xmlWork(), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        let codec: any MJCFSemanticCoding = MJCFQualificationFixtures.adapter()
        let bytes = try MJCFQualificationFixtures.translated {
            try codec.exportModel(model, expectedStamp: model.compiled.stamp, work: &work, xmlWork: &xml, actuationWork: &actuation, numericalWork: &numerical)
        }
        let document = try MJCFQualificationFixtures.translated { try BoundedXMLCodec().decode(bytes: bytes, work: &xml) }
        var namedClass = false, ref = false
        for node in document.nodes {
            if case .element(let name, let fields) = node.content {
                if name == "default", fields.contains(where: { $0.name == "class" && $0.value == "move" }) { namedClass = true }
                if name == "joint", fields.contains(where: { $0.name == "ref" && $0.value == "2" }) { ref = true }
            }
        }
        try check(namedClass && ref,"Canonical export preserves original defaults/ref hierarchy")
        let replay = try MJCFQualificationFixtures.translated {
            try codec.importModel(bytes: bytes, context: model.context, work: &work, xmlWork: &xml, actuationWork: &actuation, numericalWork: &numerical)
        }
        try check(replay.nativeDocument == model.nativeDocument,"Actual native semantic descriptor round-trip")
        let replaySample = try sample(replay,q:0.25,v:1.5,controls:[4])
        try near(replaySample.sensorValues[0],2.25,"Original physical ref after export/reimport")
        var exchange = try MJCFQualificationFixtures.exchangeWork()
        let exported = try MJCFQualificationFixtures.translated { try codec.exportNativeStructure(model, expectedStamp: model.compiled.stamp, work: &work, exchangeWork: &exchange) }
        try check(exported.loss.category == .nativeSidecars && exported.originalSource == model.context.source,"Native omission is explicit and source-attributed")
        let decoded = try MJCFQualificationFixtures.translated { try SMNXNativeModelCodec().decode(bytes: exported.bytes, work: &exchange) }
        let compiled = try MJCFQualificationFixtures.translated { try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(decoded.document.descriptor, policy: MJCFQualificationFixtures.compilerPolicy()) }
        let originalBody = try body(model,"slider")
        let nativePose = try MJCFQualificationFixtures.translated { try compiled.initialSnapshot.body(originalBody.entity).motion.pose }
        try vector(nativePose.translation,1,2,3,"Native decode/recompile original physical pose")
        try check(decoded.document == model.nativeDocument && compiled.stamp == model.compiled.stamp,"Actual native structures/source revision retained")
        try check(work.compilerCalls == 2 && exchange.operations > 0 && actuation.used > 0 && numerical.operations > 0,"Actual producer ledgers consumed")
    }
    public static func expect(_ text: String, equality: Bool = false, policy: MJCFPolicy? = nil,
                              reason: (MJCFError) -> Bool) throws(MJCFQualificationError) {
        let selected: MJCFPolicy
        if let policy { selected = policy } else { selected = try MJCFQualificationFixtures.policy() }
        var work = MJCFWork(policy: selected), xml = try MJCFQualificationFixtures.xmlWork(), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        let context = try MJCFQualificationFixtures.context(equality:equality), codec: any MJCFSemanticCoding = MJCFQualificationFixtures.adapter()
        do throws(MJCFError) { _ = try codec.importModel(bytes: Array(text.utf8), context: context, work: &work, xmlWork: &xml, actuationWork: &actuation, numericalWork: &numerical) }
        catch { try check(reason(error),"Unexpected typed MJCF rejection"); return }
        throw .assertion("Refused original input produced a model")
    }
    public static func opaqueCADAuthorityAndRetainedAssets() throws(MJCFQualificationError) {
        let original = "<mujoco><asset><mesh name='external' file='caller-owned.obj'/></asset><worldbody><body name='b' pos='1 2 3'><geom type='mesh' mesh='external'/></body></worldbody></mujoco>"
        try expect(original) { if case .lossNotSelected(_, .retainedGeometryAndContact) = $0 { true } else { false } }
        let source = try MJCFQualificationFixtures.translated { try SourceProvenance(source:"opaque-CAD-owner",revision:3) }
        let representations = try MJCFQualificationFixtures.translated {
            try BodyRepresentations(geometricShape: GeometryRepresentation(kind:.geometricShape,assetKey:"cad-shape",provenance:source,quality:.exact))
        }
        let opaque = NativeInlineAsset(key:"cad-shape",format:"opaque.native.v1",provenance:source,bytes:[0,127,255])
        let context = try MJCFQualificationFixtures.translated {
            try MJCFImportContext(identity:"cad-qualified",source:SourceProvenance(source:MJCFQualificationFixtures.source,revision:19),compilationPolicy:MJCFQualificationFixtures.compilerPolicy(),
                geometry:[MJCFGeometryBinding(bodyName:"b",representations:representations)],assets:[opaque],minimumTime:0,maximumTime:1,timeScale:1,
                equalityResidualScale:1,equalityTolerance:MJCFQualificationFixtures.tolerance())
        }
        var work = MJCFWork(policy:try MJCFQualificationFixtures.policy(losses:[.mujocoSolverExecution,.retainedGeometryAndContact,.retainedAsset])),
            xml = try MJCFQualificationFixtures.xmlWork(), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        let model = try MJCFQualificationFixtures.translated {
            try MJCFQualificationFixtures.adapter().importModel(bytes:Array(original.utf8),context:context,work:&work,xmlWork:&xml,actuationWork:&actuation,numericalWork:&numerical)
        }
        let binding = try body(model,"b")
        guard let record = model.compiled.descriptor.bodies.first(where:{$0.id == binding.entity}) else { throw .assertion("Original opaque CAD body missing") }
        try check(record.representations == representations && model.nativeDocument.assets == [opaque],"Caller CAD source/content remains authority")
        let pose = try MJCFQualificationFixtures.translated { try model.compiled.initialSnapshot.body(binding.entity).motion.pose }
        try vector(pose.translation,1,2,3,"Opaque geometry retains original real body placement")
        guard let geomLoss = model.losses.first(where:{$0.category == .retainedGeometryAndContact}),
              let assetLoss = model.losses.first(where:{$0.category == .retainedAsset}) else { throw .assertion("Original opaque losses missing") }
        guard case .element(let geom,_) = model.document.nodes[geomLoss.node].content,
              case .element(let mesh,let fields) = model.document.nodes[assetLoss.node].content else { throw .assertion("Opaque loss original element missing") }
        try check(geom == "geom" && mesh == "mesh" && fields.contains(where:{$0.name == "file" && $0.value == "caller-owned.obj"}),"Original asset filename and geometry loss remain attributable")
        try check(geomLoss.source == context.source && assetLoss.source == context.source,"Retained asset loss is original MJCF source, not CAD-owner physics")
    }
    public static func originalTypedRefusals() throws(MJCFQualificationError) {
        try expect("<mujoco><worldbody/></mujoco>",policy:MJCFQualificationFixtures.policy(losses:[])) { if case .lossNotSelected(_, .mujocoSolverExecution) = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j' type='ball'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/></body></worldbody></mujoco>") { if case .unsupported(_, "ball") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j'/></body></worldbody></mujoco>") { if case .missingField(_, "inertial") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/><body name='fixed-child'/></body></worldbody></mujoco>") { if case .missingField(_, "inertial") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j' axis='0 0 0'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/></body></worldbody></mujoco>") { if case .invalidInput(_, "axis") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='a'/><joint name='b'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/></body></worldbody></mujoco>") { if case .unsupported(_, "multiple joints per body") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'/><body name='b'/></worldbody></mujoco>") { if case .duplicate(_, "b") = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j' damping='1'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/></body></worldbody></mujoco>") { if case .unsupported(_, "damping") = $0 { true } else { false } }
        try expect("<mujoco><worldbody/><contact/></mujoco>") { if case .unsupported(_, "contact") = $0 { true } else { false } }
        try expect("<mujoco><worldbody/><actuator><motor name='m' joint='absent'/></actuator></mujoco>") { if case .danglingReference(_, "absent") = $0 { true } else { false } }
        try expect("<mujoco><worldbody/></bad>") { if case .xml(let failure) = $0 { failure.reason == .mismatchedTag } else { false } }
        try expect(MJCFQualificationFixtures.slide,equality:true,policy:MJCFQualificationFixtures.policy(losses:[.mujocoSolverExecution,.retainedRendering])) { if case .lossNotSelected(_, .softEqualitySolver) = $0 { true } else { false } }
        try expect("<mujoco><worldbody><body name='b'><joint name='j' type='slide'/><inertial pos='0 0 0' mass='1' diaginertia='1 1 1'/></body></worldbody><equality><joint name='bad' joint1='j' polycoef='0.25 1 1 0 0'/></equality></mujoco>",equality:true) { if case .unsupported(_, "nonlinear equality") = $0 { true } else { false } }
        let model = try MJCFQualificationFixtures.imported()
        do throws(MJCFQualificationError) { _ = try sample(model,q:2,v:1,controls:[4]); throw MJCFQualificationError.assertion("Original domain violation published") }
        catch MJCFQualificationError.mjcf(.constraints(.outsideDomain)) { }
        do throws(MJCFQualificationError) { _ = try sample(model,q:0,v:0,controls:[]); throw MJCFQualificationError.assertion("Wrong control shape published") }
        catch MJCFQualificationError.mjcf(.invalidInput(_, "controls")) { }
        var deniedWork = MJCFWork(policy: try MJCFQualificationFixtures.policy(losses:[.mujocoSolverExecution,.softEqualitySolver,.retainedRendering]))
        var deniedExchange = try MJCFQualificationFixtures.exchangeWork()
        var nativeRefused = false
        do throws(MJCFError) { _ = try MJCFQualificationFixtures.adapter().exportNativeStructure(model,expectedStamp:model.compiled.stamp,work:&deniedWork,exchangeWork:&deniedExchange) }
        catch { guard case .lossNotSelected(_, .nativeSidecars) = error else { throw .mjcf(error) }; nativeRefused = true }
        try check(nativeRefused && deniedExchange.operations == 0,"Native sidecar consent precedes native execution")
        var work = MJCFWork(policy: try MJCFQualificationFixtures.policy()), xml = try MJCFQualificationFixtures.xmlWork(), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        let codec: any MJCFSemanticCoding = MJCFQualificationFixtures.adapter()
        do throws(MJCFError) { _ = try codec.exportModel(model, expectedStamp: ModelStamp(identity:"other",revision:19), work:&work,xmlWork:&xml,actuationWork:&actuation,numericalWork:&numerical) }
        catch { guard case .identityMismatch = error else { throw .mjcf(error) }; return }
        throw .assertion("Wrong model stamp exported")
    }
    public static func budgetsCancellationAndReceipts() throws(MJCFQualificationError) {
        let codec: any MJCFSemanticCoding = MJCFQualificationFixtures.adapter(), context = try MJCFQualificationFixtures.context(equality:false)
        var work = MJCFWork(policy: try MJCFQualificationFixtures.policy(operations:0)), xml = try MJCFQualificationFixtures.xmlWork(), actuation = try MJCFQualificationFixtures.actuationWork(), numerical = try MJCFQualificationFixtures.numericalWork()
        var refused = false
        do throws(MJCFError) { _ = try codec.importModel(bytes:Array("<mujoco><worldbody/></mujoco>".utf8),context:context,work:&work,xmlWork:&xml,actuationWork:&actuation,numericalWork:&numerical) }
        catch { guard case .workExhausted = error else { throw .mjcf(error) }; refused = true }
        try check(refused && work.operations == 0 && xml.operations > 0,"Failure preserves actual consumed supplier work")
        try expect(MJCFQualificationFixtures.hinge,policy:MJCFQualificationFixtures.policy(bodies:1)) { if case .capacityExceeded = $0 { true } else { false } }
        try expect("<mujoco><worldbody/></mujoco>",policy:MJCFQualificationFixtures.policy(storage:0)) { if case .capacityExceeded = $0 { true } else { false } }
        try expect("<mujoco><worldbody/></mujoco>",policy:MJCFQualificationFixtures.policy(cancelled:{true})) { if case .cancelled = $0 { true } else { false } }
        var overflowWork = MJCFWork(policy: try MJCFQualificationFixtures.policy(operations:Int.max))
        try MJCFQualificationFixtures.translated { try overflowWork.charge(1) }
        var overflowRefused = false
        do throws(MJCFError) { try overflowWork.charge(Int.max) }
        catch { guard case .arithmeticOverflow = error else { throw .mjcf(error) }; overflowRefused = true }
        try check(overflowRefused && overflowWork.operations == 1,"Overflow refuses publication and retains previous work")
    }
}

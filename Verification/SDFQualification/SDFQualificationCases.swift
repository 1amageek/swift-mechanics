import SwiftMechanics

public enum SDFQualificationCases {
    public static func nestedFramesInertiaAndGravity() throws {
        let scene = try decode(SDFQualificationFixtures.nestedWorld)
        try check(scene.worldName == "fixture-world" && scene.assemblies.count == 1 && scene.losses.isEmpty,"World/assembly/loss authority")
        let model = scene.assemblies[0].model
        try check(model.descriptor.bodies.count == 2 && model.descriptor.joints.count == 1,"Nested model is one actual connected tree")
        try check(model.tree.layout.positionCount == 0 && model.tree.layout.velocityCount == 0,"Static fixed-tree q/v layout")
        try vector(frame(scene,"machine::base").initialWorldPose.translation,8,0,0,"Resolved model/world/base pose")
        try vector(frame(scene,"machine::child::tip").initialWorldPose.translation,9,2,0,"Nested link pose")
        let tool = try frame(scene,"machine::tool")
        try vector(tool.initialWorldPose.translation,9,3,1,"Forward nested relative_to pose")
        try vector(tool.placementInAttachedBody.translation,3,-1,1,"Independent attached_to placement")
        try check(tool.attachedBody == body(scene,"machine::base").id && tool.assemblyIndex == 0,"Original frame attachment owner")
        let base = try body(scene,"machine::base")
        guard let inertia = base.inertia else { throw SDFQualificationError.assertion("Explicit inertia missing") }
        try check(inertia.provenance == scene.source && inertia.quality == .exact,"Supplied inertia source/quality")
        try scalar(inertia.properties.mass,2,"Original mass")
        try vector(inertia.properties.centerOfMass,1,0,0,"Inertial pose COM in link")
        let tensor = inertia.properties.inertiaAtCenter
        try scalar(tensor.m00,3,"Rotated central inertia XX")
        try scalar(tensor.m11,2,"Rotated central inertia YY")
        try scalar(tensor.m22,4,"Rotated central inertia ZZ")
        try scalar(tensor.m01,0,"Rotated central inertia XY")
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        var work = SDFWork(policy:try SDFQualificationFixtures.policy())
        let motion = try codec.frameMotion("machine::tool",in:scene,expectedSource:scene.source,
            states:[model.descriptor.initialState],work:&work)
        try vector(motion.pose.translation,9,3,1,"Actual compiled static frame pose")
        try vector(motion.velocity.linear,0,0,0,"Actual static velocity")
        var loadsWork = try SDFQualificationFixtures.loadWork()
        let loads = try codec.initialGravityLoads(in:scene,expectedSource:scene.source,work:&loadsWork)
        try check(loads.count == 2 && loadsWork.consumed > 0,"Original physical gravity path/work")
        var total = Vector3.zero, potential = 0.0
        for response in loads {
            total = try total.adding(response.load.forces.total())
            guard let energy = response.load.potentialEnergy else { throw SDFQualificationError.assertion("Gravity potential missing") }
            potential += energy
            try check(response.load.frame == scene.worldFrame,"Gravity force frame")
            if response.load.body == base.id {
                try vector(response.load.point,8,1,0,"Gravity acts at transformed base COM")
                try vector(response.load.forces.total(),0,-20,0,"Base gravity m*g")
                try scalar(energy,20,"Base gravity -m*g dot COM")
            } else {
                try check(response.load.body == body(scene,"machine::child::tip").id,"Gravity body owner")
                try vector(response.load.point,9,2,0,"Nested link gravity COM")
                try vector(response.load.forces.total(),0,-30,0,"Nested gravity m*g")
                try scalar(energy,60,"Nested gravity potential")
            }
        }
        try vector(total,0,-50,0,"Original total gravity force")
        try scalar(potential,80,"Original total gravity potential")
    }

    public static func actualJointStateAndAttachment() throws {
        let scene = try decode(SDFQualificationFixtures.hinge)
        try check(scene.assemblies.count == 1,"Hinge assembly")
        let model = scene.assemblies[0].model, initial = model.descriptor.initialState
        try check(model.tree.layout.positionCount == 8 && model.tree.layout.velocityCount == 7,"Actual floating-base/hinge layout")
        try check(initial.q.count == 8 && initial.v.count == 7 && initial.acceleration.count == 7,"Admitted initial q/v/a counts")
        try check(initial.q[3] == 1 && initial.q[7] == 0 && initial.v.allSatisfy({ $0 == 0 }),"Explicit rest reference state")
        try vector(scene.assemblies[0].gravity.accelerationAtOrigin,0,0,-3,"Caller standalone SI gravity")
        try check(model.tree.layout.joints.count == 1,"Actual joint coordinate owner")
        let range = model.tree.layout.joints[0]
        try check(range.positions.count == 1 && range.velocities.count == 1,"Hinge manifold q/v dimensions")
        var q = initial.q, v = initial.v, acceleration = initial.acceleration
        q[range.positions.start] = Double.pi/2; v[range.velocities.start] = 2; acceleration[range.velocities.start] = 3
        let state = try KinematicState(revision:scene.source.revision,time:2,q:q,v:v,acceleration:acceleration)
        let compiled = try model.makeState(state)
        let snapshot = try model.evaluate(compiled)
        try vector(snapshot.body(body(scene,"m::arm").id).motion.pose.translation,1,0,0,"Actual compiled hinge anchor position")
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        var work = SDFWork(policy:try SDFQualificationFixtures.policy())
        let tip = try codec.frameMotion("m::tip",in:scene,expectedSource:scene.source,states:[state],work:&work)
        try vector(tip.pose.translation,1,1,0,"Attachment follows arm, not original pose reference")
        try vector(tip.velocity.angular,0,0,2,"Hinge angular rate")
        try vector(tip.velocity.linear,-2,0,0,"Offset-frame tangential velocity")
        try vector(tip.acceleration.angular,0,0,3,"Hinge angular acceleration")
        try vector(tip.acceleration.linear,-3,-4,0,"Offset-frame tangential and centripetal acceleration")
        let marker = try codec.frameMotion("m::marker",in:scene,expectedSource:scene.source,states:[state],work:&work)
        try vector(marker.pose.translation,2,0,0,"Original relative_to frame remains root-attached")
        try vector(marker.velocity.linear,0,0,0,"Independent attachment graph stationary reference")
        let exported = try codec.encode(scene,expectedSource:scene.source,work:&work)
        let restored = try decode(String(decoding:exported,as:UTF8.self))
        try check(restored.assemblies[0].model.descriptor.initialState.q[7] == 0,"Export owns original source snapshot, not evaluated runtime state")
        let stale = try KinematicState(revision:scene.source.revision+1,time:2,q:q,v:v,acceleration:acceleration)
        try expect("Stale runtime state rejected",matches:{ if case .staleSource = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.frameMotion("m::tip",in:scene,expectedSource:scene.source,states:[stale],work:&work)
        }
    }

    public static func poseConventions() throws {
        let extra = "<frame name='euler' attached_to='base'><pose>0 0 0 1.5707963267948966 1.5707963267948966 0</pose></frame>" +
            "<frame name='quaternion' attached_to='base'><pose rotation_format='quat_xyzw'>0 0 0 0 0 0.7071067811865475 0.7071067811865476</pose></frame>"
        let scene = try decode(SDFQualificationFixtures.minimal(model:extra))
        try vector(frame(scene,"m::euler").initialWorldPose.transforming(direction:.unitZ),0,-1,0,"Euler Rz*Ry*Rx order")
        try vector(frame(scene,"m::quaternion").initialWorldPose.transforming(direction:.unitX),0,1,0,"Quaternion XYZW convention")
        let defaultWorld = "<sdf version='1.12'><world name='default-world'><model name='m'><static>true</static><link name='base'>" +
            SDFQualificationFixtures.unitInertia+"</link></model></world></sdf>"
        let defaultScene = try decode(defaultWorld)
        var loadWork = try SDFQualificationFixtures.loadWork()
        let defaultLoads = try SDFQualificationFixtures.codec().initialGravityLoads(in:defaultScene,expectedSource:defaultScene.source,work:&loadWork)
        try check(defaultLoads.count == 1,"Published default world gravity load count")
        try vector(defaultLoads[0].load.forces.total(),0,0,-9.8,"Published 1.12 default world gravity actual force")
    }

    public static func originalLossSnapshotAndStaleSource() throws {
        try refused(SDFQualificationFixtures.metadata,"Default geometry/sensor/plugin refusal") {
            if case .unsupported(let element,_) = $0 { return element == "visual" }; return false
        }
        let options = try SDFQualificationFixtures.options(losses:true,assets:true)
        let scene = try decode(SDFQualificationFixtures.metadata,options:options)
        try check(scene.source == options.source && scene.assets.count == 2 && scene.losses.count == 3,"Explicit original source/assets/losses")
        try check(scene.losses.map({ $0.element }) == ["visual","sensor","plugin"],"Unserved records retained with actual loss labels")
        try check(scene.assets[0].originalPath == "model://catalog/mesh.stl" && scene.assets[1].originalPath == "model://catalog/plugin.so","Original opaque URI/filename paths")
        for asset in scene.assets { try check(asset.source == scene.source && asset.rootKey == "catalog-root" && asset.node > 0,"Original asset source/node/root authority") }
        try check(body(scene,"m::base").representations.collisionGeometry == nil,"Retained visual does not fabricate collision geometry")
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        var work = SDFWork(policy:try SDFQualificationFixtures.policy())
        let bytes = try codec.encode(scene,expectedSource:scene.source,work:&work)
        try check(bytes.elementsEqual(SDFQualificationFixtures.metadataExport.utf8),"Independent normalized original XML export bytes")
        let changed = try SDFQualificationFixtures.source(revision:8)
        try expect("Stale source export rejected",matches:{ if case .staleSource = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.encode(scene,expectedSource:changed,work:&work)
        }
        try expect("Unknown frame rejected",matches:{ if case .unknownFrame("m::absent") = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.frameMotion("m::absent",in:scene,expectedSource:scene.source,
                states:[scene.assemblies[0].model.descriptor.initialState],work:&work)
        }
        var gravityWork = try SDFQualificationFixtures.loadWork()
        try expect("No invented mass for static source gravity",matches:{ if case .missing(let element,_) = $0 { return element == "explicit mass for gravity operation" }; return false }) {
            () throws(SDFError) in _ = try codec.initialGravityLoads(in:scene,expectedSource:scene.source,work:&gravityWork)
        }
    }

    public static func semanticRefusals() throws {
        try refused(SDFQualificationFixtures.minimal(version:"1.11"),"Pinned version") { if case .unsupportedVersion("1.11") = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'><pose relative_to='absent'/></frame>"),"Unknown original pose frame") { if case .unknownFrame("m::absent") = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'/><frame name='x'/>"),"Duplicate name") { if case .duplicateName("m::x") = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'><pose relative_to='y'/></frame><frame name='y'><pose relative_to='x'/></frame>"),"Pose graph cycle") { if case .poseCycle = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x' attached_to='y'><pose relative_to='__model__'/></frame><frame name='y' attached_to='x'><pose relative_to='__model__'/></frame>"),"Separate attachment graph cycle") { if case .attachmentCycle = $0 { return true }; return false }
        for (element,extra) in [("include","<include><uri>model://catalog/a</uri></include>"),("placement_frame","<placement_frame>base</placement_frame>")] {
            try refused(SDFQualificationFixtures.minimal(model:extra),"Unsupported "+element,options:try SDFQualificationFixtures.options(losses:true,assets:true)) {
                if case .unsupported(let actual,_) = $0 { return actual == element }; return false
            }
        }
        try refused(SDFQualificationFixtures.minimal(model:"<joint name='j' type='fixed'><parent>world</parent><child>base</child></joint>"),"World joint authority") { if case .unsupported("world-parent joint",_) = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<joint name='j' type='prismatic'><parent>base</parent><child>base</child></joint>"),"Unsupported kinematics") { if case .unsupported("joint type prismatic",_) = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(link:"<inertial auto='true'/>"),"No automatic invented inertia") { if case .unsupported("auto inertia",_) = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'><pose degrees='true'/></frame>"),"Explicit radians") { if case .unsupported("degrees pose",_) = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'><pose>0 0 0 0 0 1e9999</pose></frame>"),"Nonfinite input") { if case .invalidInput = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(model:"<frame name='x'><pose>0 0 0 0 0 1e-9999</pose></frame>"),"No underflowed nonzero scalar") { if case .invalidInput = $0 { return true }; return false }
        let invalidMass = "<inertial><mass>-1</mass><inertia><ixx>1</ixx><ixy>0</ixy><ixz>0</ixz><iyy>1</iyy><iyz>0</iyz><izz>1</izz></inertia></inertial>"
        try refused(SDFQualificationFixtures.minimal(link:invalidMass),"Original physical mass rejection") { if case .model(.invalidMass) = $0 { return true }; return false }
        let invalidAxis = "<sdf version='1.12'><model name='m'><link name='root'>"+SDFQualificationFixtures.unitInertia +
            "</link><link name='arm'>"+SDFQualificationFixtures.unitInertia +
            "</link><joint name='j' type='continuous'><parent>root</parent><child>arm</child><axis><xyz>2 0 0</xyz></axis></joint></model></sdf>"
        try refused(invalidAxis,"Original unit-axis admission") { if case .invalidInput = $0 { return true }; return false }
        try refused("<sdf version='1.12'><model name='m'><link name='base'/></model></sdf>","No invented dynamic inertia") {
            if case .missing("explicit dynamic inertia",_) = $0 { return true }; return false
        }
        for path in ["model://catalog/../a","model://catalog/%2e%2e/a","model://other/a","/absolute/a"] {
            let original = SDFQualificationFixtures.minimal(link:"<visual name='x'><geometry><mesh><uri>"+path+"</uri></mesh></geometry></visual>")
            try refused(original,"Opaque root admission "+path,options:try SDFQualificationFixtures.options(losses:true,assets:true)) { if case .assetRejected(let rejected) = $0 { return rejected == path }; return false }
        }
    }

    public static func capacitiesAndReceipts() throws {
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        let options = try SDFQualificationFixtures.options(), compilation = try SDFQualificationFixtures.compilation()
        let bytes = Array(SDFQualificationFixtures.minimal().utf8)
        var operations = SDFWork(policy:try SDFQualificationFixtures.policy(operations:0))
        try expect("Semantic operation bound",matches:{ if case .numerical(.resourceLimit(resource:.arithmeticOperations,limit:0)) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.decode(bytes:bytes,options:options,compilationPolicy:compilation,work:&operations)
        }
        var storage = SDFWork(policy:try SDFQualificationFixtures.policy(storage:0))
        try expect("Semantic storage bound",matches:{ if case .numerical(.resourceLimit(resource:.scalarStorage,limit:0)) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.decode(bytes:bytes,options:options,compilationPolicy:compilation,work:&storage)
        }
        try check(storage.xml.operations > 0 && storage.semantics.operations > 0,"Refused admission retains actual consumed parser/semantic work")
        var iterations = SDFWork(policy:try SDFQualificationFixtures.policy(iterations:0))
        try expect("Semantic graph iteration bound",matches:{ if case .numerical(.resourceLimit(resource:.iterations,limit:0)) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.decode(bytes:bytes,options:options,compilationPolicy:compilation,work:&iterations)
        }
        try refused(SDFQualificationFixtures.minimal(),"Named record capacity",policy:try SDFQualificationFixtures.policy(named:1)) { if case .invalidInput = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(),"Original token bound",policy:try SDFQualificationFixtures.policy(token:2)) { if case .invalidInput = $0 { return true }; return false }
        try refused(SDFQualificationFixtures.minimal(),"XML node capacity",policy:try SDFQualificationFixtures.policy(xmlNodes:0)) { if case .xml(let failure) = $0 { return failure.reason == .limit(.nodes,0) }; return false }
        try refused(SDFQualificationFixtures.minimal(),"Actual compiler capacity",compilation:try SDFQualificationFixtures.compilation(records:0)) {
            if case .compilation(let failure) = $0 { return failure.diagnostics.contains(where:{ $0.code == .capacityExceeded }) }; return false
        }
        let scene = try decode(SDFQualificationFixtures.nestedWorld)
        var output = SDFWork(policy:try SDFQualificationFixtures.policy(xmlOutput:0))
        try expect("Original export output capacity",matches:{ if case .xml(let failure) = $0 { return failure.reason == .limit(.outputBytes,0) }; return false }) {
            () throws(SDFError) in _ = try codec.encode(scene,expectedSource:scene.source,work:&output)
        }
        var gravity = try SDFQualificationFixtures.loadWork(operations:0)
        try expect("Original gravity work bound",matches:{ if case .load(.workExhausted) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.initialGravityLoads(in:scene,expectedSource:scene.source,work:&gravity)
        }
        var cancelled = try SDFQualificationFixtures.loadWork(cancelled:{ true })
        try expect("Caller gravity cancellation",matches:{ if case .load(.cancelled) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.initialGravityLoads(in:scene,expectedSource:scene.source,work:&cancelled)
        }
    }

    public static func cancellationScene() throws -> SDFScene { try decode(SDFQualificationFixtures.nestedWorld) }

    /// Invoke only inside an actually cancelled Native Task; synchronous target entry does not call this case.
    public static func cancelledTask(_ scene: SDFScene) throws {
        try check(Task.isCancelled,"Cancellation case has an actual cancelled task")
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        let options = try SDFQualificationFixtures.options(), compilation = try SDFQualificationFixtures.compilation()
        var work = SDFWork(policy:try SDFQualificationFixtures.policy())
        try expect("Cancelled decode",matches:isSemanticCancellation) {
            () throws(SDFError) in _ = try codec.decode(bytes:Array(SDFQualificationFixtures.minimal().utf8),options:options,compilationPolicy:compilation,work:&work)
        }
        try expect("Cancelled encode",matches:isSemanticCancellation) {
            () throws(SDFError) in _ = try codec.encode(scene,expectedSource:scene.source,work:&work)
        }
        try expect("Cancelled frame query",matches:isSemanticCancellation) {
            () throws(SDFError) in _ = try codec.frameMotion("machine::tool",in:scene,expectedSource:scene.source,
                states:[scene.assemblies[0].model.descriptor.initialState],work:&work)
        }
        var gravity = try SDFQualificationFixtures.loadWork()
        try expect("Cancelled gravity query",matches:{ if case .load(.cancelled) = $0 { return true }; return false }) {
            () throws(SDFError) in _ = try codec.initialGravityLoads(in:scene,expectedSource:scene.source,work:&gravity)
        }
    }

    private static func isSemanticCancellation(_ error: SDFError) -> Bool { if case .numerical(.cancelled) = error { return true }; return false }

    private static func decode(_ xml: String, options: SDFImportOptions? = nil, policy: SDFPolicy? = nil,
                               compilation: CompilationPolicy? = nil) throws -> SDFScene {
        var work = SDFWork(policy:try policy ?? SDFQualificationFixtures.policy())
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        return try codec.decode(bytes:Array(xml.utf8),options:options ?? SDFQualificationFixtures.options(),
            compilationPolicy:compilation ?? SDFQualificationFixtures.compilation(),work:&work)
    }

    private static func refused(_ xml: String, _ message: String, options: SDFImportOptions? = nil,
                                policy: SDFPolicy? = nil, compilation: CompilationPolicy? = nil,
                                matches: (SDFError) -> Bool) throws {
        var work = SDFWork(policy:try policy ?? SDFQualificationFixtures.policy())
        let selectedOptions = try options ?? SDFQualificationFixtures.options()
        let selectedCompilation = try compilation ?? SDFQualificationFixtures.compilation()
        let codec: any SDFDocumentCoding = SDFQualificationFixtures.codec()
        try expect(message,matches:matches) { () throws(SDFError) in
            _ = try codec.decode(bytes:Array(xml.utf8),options:selectedOptions,compilationPolicy:selectedCompilation,work:&work)
        }
    }

    private static func expect(_ message: String, matches: (SDFError) -> Bool,
                               operation: () throws(SDFError) -> Void) throws {
        do throws(SDFError) { try operation() }
        catch { try check(matches(error),message+": wrong typed failure"); return }
        throw SDFQualificationError.assertion(message+": unexpected successful publication")
    }

    private static func frame(_ scene: SDFScene, _ name: String) throws -> SDFResolvedFrame {
        guard let frame = scene.frames.first(where:{ $0.scopedName == name }) else { throw SDFQualificationError.assertion("Missing original frame "+name) }
        return frame
    }

    private static func body(_ scene: SDFScene, _ name: String) throws -> BodyRecord3D {
        let id = try EntityID(kind:.body,key:"sdf-fixture:body:"+name)
        for assembly in scene.assemblies { for original in assembly.model.descriptor.bodies {
            if original.id == id, case .spatial(let record) = original { return record }
        } }
        throw SDFQualificationError.assertion("Missing original body "+name)
    }

    private static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ message: String) throws {
        try scalar(actual.x,x,message+" X"); try scalar(actual.y,y,message+" Y"); try scalar(actual.z,z,message+" Z")
    }
    private static func scalar(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && abs(actual-expected) <= 2e-10+1e-11*abs(expected),message)
    }
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw SDFQualificationError.assertion(message) }
    }
}

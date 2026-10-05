import MJCFQualificationSupport

@main
struct MJCFQualification {
    static func main() throws(MJCFQualificationError) {
        try MJCFQualificationCases.originalSlideDefaultsAndInertia(); print("MJCF original rotated slide/default/inertia/source witness passed")
        try MJCFQualificationCases.originalOffsetHingeAndDegreeReference(); print("MJCF original shifted hinge/degree-reference/motion witness passed")
        try MJCFQualificationCases.originalAffinePowerSensorsAndEquality(); print("MJCF original motor power/sensor units/physical equality witness passed")
        try MJCFQualificationCases.sourceLossProvenanceAndExport(); print("MJCF original losses/default-preserving export/native decode-recompile witness passed")
        try MJCFQualificationCases.opaqueCADAuthorityAndRetainedAssets(); print("MJCF opaque CAD authority/original geometry-asset loss witness passed")
        try MJCFQualificationCases.originalTypedRefusals(); print("MJCF original unsupported/schema/source/domain rejection witness passed")
        try MJCFQualificationCases.budgetsCancellationAndReceipts(); print("MJCF original bounded work/cancellation/supplier receipt witness passed")
        print("MJCF selected synchronous public witnesses completed")
    }
}

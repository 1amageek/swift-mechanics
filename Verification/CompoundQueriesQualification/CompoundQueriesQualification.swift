#if canImport(CompoundQueriesQualificationSupport)
import CompoundQueriesQualificationSupport
#endif

@main
struct CompoundQueriesQualification {
    static func main() throws {
        try CompoundQueriesQualificationCases.transformedOriginalWitnesses(); print("compound:transformed-original:pass")
        try CompoundQueriesQualificationCases.deterministicPairsAndRays(); print("compound:pair-ray-order:pass")
        try CompoundQueriesQualificationCases.originalAnalyticFeatures(); print("compound:original-features:pass")
        try CompoundQueriesQualificationCases.filtersFidelityAndExplicitRefusal(); print("compound:filters-refusals:pass")
        try CompoundQueriesQualificationCases.admissionAndMetadataBoundaries(); print("compound:bounded-admission:pass")
        try CompoundQueriesQualificationCases.exactWorkAndResourceBoundaries(); print("compound:exact-work:pass")
        try CompoundQueriesQualificationCases.transactionalLateRefusals(); print("compound:transactional-failure:pass")
    }
}

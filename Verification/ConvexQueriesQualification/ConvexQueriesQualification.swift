import SwiftMechanics
#if canImport(ConvexQueriesQualificationSupport)
import ConvexQueriesQualificationSupport
#endif

@main
struct ConvexQueriesQualification {
    static func main() throws {
        try ConvexQueriesQualificationCases.originalSupportMaps(); print("PASS original support maps")
        try ConvexQueriesQualificationCases.adaptedSeparationAndReversal(); print("PASS adapted separation and reversal")
        try ConvexQueriesQualificationCases.primitiveAndHullSeparation(); print("PASS primitive and hull GJK separation")
        try ConvexQueriesQualificationCases.originalBoxPenetration(); print("PASS original box EPA penetration")
        try ConvexQueriesQualificationCases.primitiveAndHullPenetration(); print("PASS primitive and hull EPA penetration")
        try ConvexQueriesQualificationCases.touchingAndCoincidentBoxes(); print("PASS touching and coincident boxes")
        try ConvexQueriesQualificationCases.rigidCovarianceAndSnapshot(); print("PASS rigid covariance and snapshots")
        try ConvexQueriesQualificationCases.identitySourceAndAdmission(); print("PASS original identity source and admission")
        try ConvexQueriesQualificationCases.boundedWorkAndIterationRefusals(); print("PASS bounded work and iteration refusals")
    }
}

import SwiftMechanics
import Testing

@Suite struct LumpedLawTests {
    @Test func motorIndependentCircuitAndDiscreteEnergy() throws {
        let binding=try ActuationFixtures.binding(kind:.motor),state=try ActuationFixtures.state(binding,primary:1)
        let law=try DCMotorLaw(binding:binding,inductanceHenries:2,resistanceOhms:2,reciprocalConstant:1,viscousDamping:0.5,maximumVoltage:12,maximumCurrent:100,maximumSpeed:10)
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical();let evaluator:any LumpedActuatorEvaluating=ReferenceLumpedActuatorEvaluator()
        let response=try evaluator.motor(law:law,state:state,sample:ActuationFixtures.sample(binding,velocity:2),voltage:10,dt:0.5,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(response.state.primary == 2 && response.appliedEffort == 1 && response.power == 2)
        #expect(response.energy.sourceWork == 10 && response.energy.mechanicalWork == 1)
        #expect(response.energy.storedAfter-response.energy.storedBefore == 3)
        #expect(response.energy.physicalLoss == 5 && response.energy.numericalLoss == 1 && response.energy.balanceResidual == 0)
        #expect(2*(response.state.primary-state.primary)/0.5 == 10-2*response.state.primary-2)
        #expect(state.primary == 1 && state.time == 0)
    }
    @Test func unloadedMotorGeometricStepResponseClippingAndGenerator() throws {
        let binding=try ActuationFixtures.binding(kind:.motor),law=try DCMotorLaw(binding:binding,inductanceHenries:2,resistanceOhms:2,reciprocalConstant:1,viscousDamping:0,maximumVoltage:4,maximumCurrent:100,maximumSpeed:10)
        var state=try ActuationFixtures.state(binding),work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical();let evaluator:any LumpedActuatorEvaluating=ReferenceLumpedActuatorEvaluator()
        for _ in 0..<10 {
            let response=try evaluator.motor(law:law,state:state,sample:ActuationFixtures.sample(binding,time:state.time),voltage:8,dt:1,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
            #expect(response.clipped && response.energy.physicalLoss >= 0 && response.energy.numericalLoss >= 0);state=response.state
        }
        #expect(state.primary == 2*(1-1.0/1024))
        let generated=try evaluator.motor(law:law,state:ActuationFixtures.state(binding),sample:ActuationFixtures.sample(binding,velocity:2),voltage:0,dt:1,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(generated.state.primary == -0.5 && generated.power == -1 && generated.energy.sourceWork == 0)
        #expect(generated.energy.storedAfter+generated.energy.physicalLoss+generated.energy.numericalLoss == -generated.energy.mechanicalWork)
    }
    @Test func chamberCompressibilityPortBalanceAndLeakage() throws {
        let binding=try ActuationFixtures.binding(kind:.fluid,coordinate:.translation),state=try ActuationFixtures.state(binding,primary:2)
        let law=try LinearChamberLaw(binding:binding,referenceVolume:1,bulkModulus:2,area:0.25,leakage:0,maximumPressure:100,maximumFlow:1,maximumStroke:1,maximumRelativeVolumeChange:0.5)
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical();let evaluator:any LumpedActuatorEvaluating=ReferenceLumpedActuatorEvaluator()
        let response=try evaluator.chamber(law:law,state:state,sample:ActuationFixtures.sample(binding,velocity:0.5),flow:0.375,dt:0.5,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(response.state.primary == 2.25 && response.appliedEffort == 0.5625)
        #expect(response.energy.sourceWork == 0.421875 && response.energy.mechanicalWork == 0.140625)
        #expect(response.energy.numericalLoss == 0.015625 && response.energy.physicalLoss == 0 && response.energy.balanceResidual == 0)
        #expect(law.compliance*(response.state.primary-2)/0.5 == 0.375-0.25*0.5)
        let leaky=try LinearChamberLaw(binding:binding,referenceVolume:1,bulkModulus:2,area:0.25,leakage:0.5,maximumPressure:100,maximumFlow:1,maximumStroke:1,maximumRelativeVolumeChange:0.5)
        let steady=try evaluator.chamber(law:leaky,state:state,sample:ActuationFixtures.sample(binding),flow:1,dt:0.5,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(steady.state.primary == 2 && steady.energy.sourceWork == 1 && steady.energy.physicalLoss == 1)
    }
    @Test func selectedMuscleActivationHillLawAndPassiveWork() throws {
        let binding=try ActuationFixtures.binding(kind:.muscle,coordinate:.translation),law=try SelectedMuscleLaw(binding:binding,maximumForce:100,optimalLength:1,lengthWidth:0.5,
            maximumShorteningSpeed:1,maximumLengtheningSpeed:1,hillCurvature:0.5,eccentricGain:1.5,activationTimeConstant:0.5,passiveStiffness:16,slackLength:1)
        let state=try ActuationFixtures.state(binding,primary:0.5)
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical();let evaluator:any LumpedActuatorEvaluating=ReferenceLumpedActuatorEvaluator()
        let isometric=try evaluator.muscle(law:law,state:state,sample:ActuationFixtures.sample(binding,position:1),activation:1,dt:0.5,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(isometric.state.primary == 0.75 && isometric.appliedEffort == -75 && isometric.power == 0)
        let stretched=try evaluator.muscle(law:law,state:state,sample:ActuationFixtures.sample(binding,position:1,velocity:0.25),activation:1,dt:0.5,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        let active=100*0.75*0.75*((1+1.5*0.25)/(1+0.25)),passive=16.0*0.125
        #expect(stretched.appliedEffort == -active-passive)
        #expect(stretched.energy.storedAfter == 0.125 && stretched.energy.numericalLoss == 0.125)
        #expect(abs(stretched.energy.balanceResidual) < 1e-12)
        let shortened=try evaluator.muscle(law:law,state:state,sample:ActuationFixtures.sample(binding,position:1,velocity:-0.5),activation:1,dt:0.25,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        let activation=(0.5+0.5)/(1+0.5),force=100*activation*0.75*((1-0.5)/(1+1.0))
        #expect(abs(shortened.appliedEffort+force) < 1e-12 && shortened.power > 0)
    }
    @Test func invalidParametersAndAdmittedEnvelopesFailExplicitly() throws {
        let motor=try ActuationFixtures.binding(kind:.motor),fluid=try ActuationFixtures.binding(kind:.fluid,coordinate:.translation)
        #expect(throws:ActuationError.invalidLaw) { try DCMotorLaw(binding:motor,inductanceHenries:0,resistanceOhms:1,reciprocalConstant:1,viscousDamping:0,maximumVoltage:10,maximumCurrent:100,maximumSpeed:10) }
        #expect(throws:ActuationError.invalidLaw) { try LinearChamberLaw(binding:fluid,referenceVolume:0,bulkModulus:1,area:1,leakage:0,maximumPressure:100,maximumFlow:1,maximumStroke:1,maximumRelativeVolumeChange:0.5) }
        let law=try LinearChamberLaw(binding:fluid,referenceVolume:1,bulkModulus:2,area:0.25,leakage:0,maximumPressure:100,maximumFlow:1,maximumStroke:1,maximumRelativeVolumeChange:0.1)
        var work=try ActuationFixtures.work(),numeric=try ActuationFixtures.numerical();let evaluator:any LumpedActuatorEvaluating=ReferenceLumpedActuatorEvaluator()
        #expect(throws:ActuationError.outsideDomain) { try evaluator.chamber(law:law,state:ActuationFixtures.state(fluid),sample:ActuationFixtures.sample(fluid),flow:-1,dt:1,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
        #expect(throws:ActuationError.outsideDomain) { try evaluator.chamber(law:law,state:ActuationFixtures.state(fluid,primary:2),sample:ActuationFixtures.sample(fluid,velocity:1),flow:1,dt:1,tolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
        #expect(throws:ActuationError.outsideDomain) { try ActuationFixtures.state(motor,primary:101) }
    }
}

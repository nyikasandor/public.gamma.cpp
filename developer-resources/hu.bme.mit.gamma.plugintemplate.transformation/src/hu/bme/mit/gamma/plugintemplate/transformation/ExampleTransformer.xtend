package hu.bme.mit.gamma.plugintemplate.transformation

import hu.bme.mit.gamma.plugintemplate.transformation.patterns.ChoiceStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.DeepHistoryStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.ForkStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.InitialStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.JoinStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.MergeStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.Packages
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.Regions
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.ShallowHistoryStates
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.Statecharts
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.States
import hu.bme.mit.gamma.plugintemplate.transformation.patterns.Transitions
import hu.bme.mit.gamma.statechart.model.CompositeElement
import hu.bme.mit.gamma.statechart.model.Package
import hu.bme.mit.gamma.statechart.model.Region
import hu.bme.mit.gamma.statechart.model.State
import hu.bme.mit.gamma.statechart.model.StatechartDefinition
import hu.bme.mit.gamma.statechart.model.StatechartModelFactory
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine
import org.eclipse.viatra.query.runtime.emf.EMFScope
import org.eclipse.viatra.transformation.runtime.emf.rules.batch.BatchTransformationRule
import org.eclipse.viatra.transformation.runtime.emf.rules.batch.BatchTransformationRuleFactory
import org.eclipse.viatra.transformation.runtime.emf.transformation.batch.BatchTransformation
import org.eclipse.viatra.transformation.runtime.emf.transformation.batch.BatchTransformationStatements

import static com.google.common.base.Preconditions.checkState

class ExampleTransformer {

	// Transformation-related extensions
	protected final extension BatchTransformation transformation
	protected final extension BatchTransformationStatements statements
	// Transformation rule-related extensions
	protected final extension BatchTransformationRuleFactory = new BatchTransformationRuleFactory
	protected final extension StatechartModelFactory = StatechartModelFactory.eINSTANCE

	protected ViatraQueryEngine engine
	protected Resource resource

	protected Trace trace

	protected BatchTransformationRule<Packages.Match, Packages.Matcher> packagesRule
	protected BatchTransformationRule<Statecharts.Match, Statecharts.Matcher> statechartsRule
	protected BatchTransformationRule<Regions.Match, Regions.Matcher> regionsRule
	protected BatchTransformationRule<InitialStates.Match, InitialStates.Matcher> initialStatesRule
	protected BatchTransformationRule<ShallowHistoryStates.Match, ShallowHistoryStates.Matcher> shallowHistoryStatesRule
	protected BatchTransformationRule<DeepHistoryStates.Match, DeepHistoryStates.Matcher> deepHistoryStatesRule
	protected BatchTransformationRule<ChoiceStates.Match, ChoiceStates.Matcher> choiceStatesRule
	protected BatchTransformationRule<MergeStates.Match, MergeStates.Matcher> mergeStatesRule
	protected BatchTransformationRule<ForkStates.Match, ForkStates.Matcher> forkStatesRule
	protected BatchTransformationRule<JoinStates.Match, JoinStates.Matcher> joinStatesRule
	protected BatchTransformationRule<States.Match, States.Matcher> statesRule
	protected BatchTransformationRule<Transitions.Match, Transitions.Matcher> transitionsRule

	new(Resource resource) {
		this.resource = resource
		// Create EMF scope and EMF IncQuery engine based on the resource
		val scope = new EMFScope(resource)
		this.engine = ViatraQueryEngine.on(scope);
		this.trace = null
		// Create VIATRA Batch transformation
		transformation = BatchTransformation.forEngine(engine).build
		// Initialize batch transformation statements
		statements = transformation.transformationStatements
	}

	def execute() {
		getPackagesRule.fireAllCurrent
		getStatechartsRule.fireAllCurrent
		while (!isEachRegionIsTransformed) {
			getRegionsRule.fireAllCurrent[!trace.isRegionMapped(it.region) && trace.isCompositeElementMapped(it.region.eContainer as CompositeElement)]
			getStatesRule.fireAllCurrent[!trace.isCompositeElementMapped(it.state) && trace.isRegionMapped(it.state.eContainer as Region)]
		}
		getInitialStatesRule.fireAllCurrent
		getShallowHistoryStatesRule.fireAllCurrent
		getDeepHistoryStatesRule.fireAllCurrent
		getChoiceStatesRule.fireAllCurrent
		getMergeStatesRule.fireAllCurrent
		getForkStatesRule.fireAllCurrent
		getJoinStatesRule.fireAllCurrent
		getTransitionsRule.fireAllCurrent
		return trace
	}

	private def isEachRegionIsTransformed() {
		return Regions.Matcher.on(engine).allValuesOfregion.forall[trace.isRegionMapped(it)]
	}

	private def getPackagesRule() {
		if (packagesRule === null) {
			packagesRule = createRule(Packages.instance).action [
				checkState(trace === null)
				val sourcePackage = it.package
				val targetPackage = createPackage => [
					it.name = sourcePackage.name
				]
				this.trace = new Trace(sourcePackage, targetPackage)
				trace.put(sourcePackage, targetPackage)
			].build
		}
		return packagesRule
	}
	
	private def getStatechartsRule() {
		if (statechartsRule === null) {
			statechartsRule = createRule(Statecharts.instance).action [
				val sourceStatechart = it.statechart
				val targetStatechart = createStatechartDefinition => [
					it.name = sourceStatechart.name
				]
				val sourceParentPackage = sourceStatechart.eContainer as Package
				val targetParentPackage = trace.getTargetPackage(sourceParentPackage)
				targetParentPackage.components += targetStatechart
				trace.put(sourceStatechart, targetStatechart)
			].build
		}
		return statechartsRule
	}
	
	private def getRegionsRule() {
		if (regionsRule === null) {
			regionsRule = createRule(Regions.instance).action [
				val sourceRegion = it.region
				val targetRegion = createRegion => [
					it.name = sourceRegion.name
				]
				val sourceParent = sourceRegion.eContainer as CompositeElement
				var CompositeElement targetParent = if (sourceParent instanceof StatechartDefinition) {
					trace.getTargetStatechart(sourceParent)
				} else if (sourceParent instanceof State) {
					trace.getTargetState(sourceParent)
				}
				targetParent.regions += targetRegion
				trace.put(sourceRegion, targetRegion)
			].build
		}
		return regionsRule
	}
	
	private def getInitialStatesRule() {
		if (initialStatesRule === null) {
			initialStatesRule = createRule(InitialStates.instance).action [
				val sourceInitialState = it.initialState
				val targetInitialState = createInitialState => [
					it.name = sourceInitialState.name
				]
				val sourceParent = sourceInitialState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetInitialState
				trace.put(sourceInitialState, targetInitialState)
			].build
		}
		return initialStatesRule
	}
	
	private def getShallowHistoryStatesRule() {
		if (shallowHistoryStatesRule === null) {
			shallowHistoryStatesRule = createRule(ShallowHistoryStates.instance).action [
				val sourceShallowHistoryState = it.shallowHistoryState
				val targetShallowHistoryState = createShallowHistoryState => [
					it.name = sourceShallowHistoryState.name
				]
				val sourceParent = sourceShallowHistoryState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetShallowHistoryState
				trace.put(sourceShallowHistoryState, targetShallowHistoryState)
			].build
		}
		return shallowHistoryStatesRule
	}
	
	private def getDeepHistoryStatesRule() {
		if (deepHistoryStatesRule === null) {
			deepHistoryStatesRule = createRule(DeepHistoryStates.instance).action [
				val sourceDeepHistoryState = it.deepHistoryState
				val targetDeepHistoryState = createDeepHistoryState => [
					it.name = sourceDeepHistoryState.name
				]
				val sourceParent = sourceDeepHistoryState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetDeepHistoryState
				trace.put(sourceDeepHistoryState, targetDeepHistoryState)
			].build
		}
		return deepHistoryStatesRule
	}
	
	private def getChoiceStatesRule() {
		if (choiceStatesRule === null) {
			choiceStatesRule = createRule(ChoiceStates.instance).action [
				val sourceChoiceState = it.choiceState
				val targetChoiceState = createChoiceState => [
					it.name = sourceChoiceState.name
				]
				val sourceParent = sourceChoiceState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetChoiceState
				trace.put(sourceChoiceState, targetChoiceState)
			].build
		}
		return choiceStatesRule
	}
	
	private def getMergeStatesRule() {
		if (mergeStatesRule === null) {
			mergeStatesRule = createRule(MergeStates.instance).action [
				val sourceMergeState = it.mergeState
				val targetMergeState = createMergeState => [
					it.name = sourceMergeState.name
				]
				val sourceParent = sourceMergeState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetMergeState
				trace.put(sourceMergeState, targetMergeState)
			].build
		}
		return mergeStatesRule
	}
	
	private def getForkStatesRule() {
		if (forkStatesRule === null) {
			forkStatesRule = createRule(ForkStates.instance).action [
				val sourceForkState = it.forkState
				val targetForkState = createForkState => [
					it.name = sourceForkState.name
				]
				val sourceParent = sourceForkState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetForkState
				trace.put(sourceForkState, targetForkState)
			].build
		}
		return forkStatesRule
	}
	
	private def getJoinStatesRule() {
		if (joinStatesRule === null) {
			joinStatesRule = createRule(JoinStates.instance).action [
				val sourceJoinState = it.joinState
				val targetJoinState = createJoinState => [
					it.name = sourceJoinState.name
				]
				val sourceParent = sourceJoinState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetJoinState
				trace.put(sourceJoinState, targetJoinState)
			].build
		}
		return joinStatesRule
	}
	
	private def getStatesRule() {
		if (statesRule === null) {
			statesRule = createRule(States.instance).action [
				val sourceState = it.state
				val targetState = createState => [
					it.name = sourceState.name
				]
				val sourceParent = sourceState.eContainer as Region
				var targetParent = trace.getTargetRegion(sourceParent)
				targetParent.stateNodes += targetState
				trace.put(sourceState, targetState)
			].build
		}
		return statesRule
	}

	private def getTransitionsRule() {
		if (transitionsRule === null) {
			transitionsRule = createRule(Transitions.instance).action [
				val sourceTransition = it.transition
				val sourceStatechart = sourceTransition.eContainer as StatechartDefinition
				val sourceTransitionSource = sourceTransition.sourceState
				var sourceTransitionTarget = sourceTransition.targetState
				
				val targetTransitionSource = trace.getTargetStateNode(sourceTransitionSource)
				val targetTransitionTarget = trace.getTargetStateNode(sourceTransitionTarget)
				
				val targetTransition = createTransition => [
					it.sourceState = targetTransitionSource
					it.targetState = targetTransitionTarget
				]
				
				val targetStatechart = trace.getTargetStatechart(sourceStatechart)
				targetStatechart.transitions += targetTransition
				trace.put(sourceTransition, targetTransition)
			].build
		}
		return transitionsRule
	}

	def dispose() {
		if (transformation !== null) {
			transformation.ruleEngine.dispose
		}
		return
	}
}

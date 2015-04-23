$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll, concat} = require 'prelude-ls'
nj = require 'numeric'
vm = require './vmath.ls'
{LinInterp, getDim, add, mul, pow, sub, sum, sqrt} = vm
{VelocityThreshold, GreedyPiecewiseLinearFit, GreedyOlp, NaiveOlp} = require './segmentation.ls'

require! mersennetwister

groupBy = (f, xs) ->
	idx = new Map()
	for x in xs
		key = f x
		if not idx.has key
			grp = []
			idx.set key, grp
		idx.get(key).push x
	return idx

algorithms = [
	#* id: \greedyOlp, name: "Greedy OLP", fitter: (opts) -> GreedyOlp([opts.noiseLevel]*2)~fit
	id: \naiveOlp, name: "Naive OLP", fitter: (opts) -> NaiveOlp([opts.noiseLevel]*2)~fit
	]
	#* id: \dummy, name: "No partitioning", fitter: (opts) -> (t, x) -> (new vm.LinearFit ts: t, xs: x)~predict
	#* id: \raw, name: "No filtering", fitter: (opts) -> (t, x) -> vm.LinInterp t, x

targets =
	* {id: \hybrid, name: "Pursuit and saccade", duration: 0.5, generator: gazeSimulation.RandomLinearMovementSimulator}
	* {id: \singleSaccade, name: "Single saccade", duration: 2, generator: gazeSimulation.StepSimulator}
	* {id: \singleFixation, name: "Single fixation", duration: 2, generator: -> (dt) -> [0, 0]}

dynamics =
	* id: \bessel, name: "Bessel dynamics", dynamic: gazeSimulation.BesselEyeDynamics
	* id: \trivial, name: "No dynamics", dynamic: -> (x) -> x

$ ->
	$ '#tmp-plot' .hide!
	targetGen = targets[0]
	dynamic = dynamics[0]
	noiseLevel = 0.5
	noiseLevels = [1e-3 to 5 by 1]
	nIters = 5
	seed = undefined
	Math.random = (new mersennetwister seed)~random

	dt = 0.01
	simulateTrial = (noiseLevel) ->
		sim = gazeSimulation.SignalSimulator do
			target: targetGen.generator!
			duration: targetGen.duration, dt: dt
			dynamics: dynamic.dynamic dt: dt
			noise: gazeSimulation.NdNormNoise [noiseLevel]*2
		sim!
	{ts, gaze, target, measurement} = simulateTrial noiseLevel

	samplePlot = mplot.Plot!
		..plot ts, (getDim 0) gaze
			..classed \gaze-plot, true
		..scatter ts, (getDim 0) measurement
			..classed \measurement-plot, true
		..xlabel "Time (s)"
		..ylabel "Horizontal position (degrees)"

	scanpathPlot = mplot.Plot!
		..plot ...zipAll ...gaze
			..classed \gaze-plot, true
		..scatter ...zipAll ...measurement
			..classed \measurement-plot, true
		..xlabel "Horizontal position (degrees)"
		..ylabel "Vertical position (degrees)"

	for {id, name, fitter} in algorithms
		fit = fitter(noiseLevel: noiseLevel) ts, measurement
		[x, y] = zipAll ...fit(ts)

		samplePlot.plot ts, x, label: name
			..classed "recon-#{id}"

		scanpathPlot.plot x, y, label: name
			..classed "recon-#{id}"

	samplePlot.show $ '#sample-trial-plot'
	scanpathPlot.show $ '#scanpath-plot'

	rmse = (x, y) ->
		diffs = nj.sub x, y |> (nj.pow _, 2)
		rse = sum nj.sqrt (add ...nj.transpose diffs)
		mrse = rse / x.length
		return mrse

	benchmarkOne = (noiseLevel) ->
		{ts, gaze, target, measurement} = simulateTrial noiseLevel
		actualNoise = rmse measurement, gaze
		for algorithm in algorithms
			fitter = algorithm.fitter noiseLevel: noiseLevel
			fit = fitter(ts, measurement) ts
			algorithm: algorithm
			noiseLevel: noiseLevel
			actualNoise: actualNoise
			rmse: (rmse fit, gaze)

	benchmarkNoiseLevel = (noiseLevel) ->
		concat map benchmarkOne, [noiseLevel]*nIters

	benchmark = ->
		concat map benchmarkNoiseLevel, noiseLevels

	mrsePlot = mplot.Plot!
		..xlabel "Noise reduction (degrees)"
		..ylabel "Root mean square error (degrees)"

	(groupBy (.algorithm), benchmark!).forEach (result, algorithm) ->
		stats = []
		(groupBy (.noiseLevel), result).forEach (r, level) ->
			stats.push [level, vm.mean r.map (.rmse)]
		[x, y] = zipAll ...stats
		mrsePlot.plot x, y, label: algorithm.name
	mrsePlot.show $ \#mrse-plot

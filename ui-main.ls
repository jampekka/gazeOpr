$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll, concat} = require 'prelude-ls'
nj = require './numeric.js'
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

algorithms =
	* id: \greedyOlp, name: "Greedy OLP", fitter: (opts) -> GreedyOlp([opts.noiseLevel]*2)~fit
	* id: \naiveOlp, name: "Naive OLP", fitter: (opts) -> NaiveOlp([opts.noiseLevel]*2)~fit
	#* id: \dummy, name: "No partitioning", fitter: (opts) -> (t, x) -> (vm.LinearFit ts: t, xs: x)
	#* id: \raw, name: "No filtering", fitter: (opts) -> (t, x) -> vm.LinInterp t, x

targets =
	* {id: \hybrid, name: "Pursuit and saccade", duration: 5, generator: gazeSimulation.RandomLinearMovementSimulator}
	* {id: \singleSaccade, name: "Single saccade", duration: 2, generator: gazeSimulation.StepSimulator}
	* {id: \singleFixation, name: "Single fixation", duration: 2, generator: -> (dt) -> [0, 0]}

dynamics =
	* id: \bessel, name: "Bessel dynamics", dynamic: gazeSimulation.BesselEyeDynamics
	* id: \trivial, name: "No dynamics", dynamic: -> (x) -> x

$ ->
	$ '#tmp-plot' .hide!
	targetGen = targets[0]
	dynamic = dynamics[1]
	noiseLevel = 0.5
	noiseLevels = [1e-3 to 5 by 1]
	nIters = 5
	seed = 0
	Math.random = (new mersennetwister 0)~random

	simulateTrial = (noiseLevel) ->
		sim = gazeSimulation.SignalSimulator do
			target: targetGen.generator!
			duration: targetGen.duration, dt: 0.01
			dynamics: dynamic.dynamic!
			noise: gazeSimulation.NdNormNoise [noiseLevel]*2
		sim!
	{ts, gaze, target, measurement} = simulateTrial noiseLevel

	samplePlot = mplot.Plot!
		..plot ts, (getDim 0) gaze
			..classed \gaze-plot, true
		..scatter ts, (getDim 0) measurement
			..classed \measurement-plot, true
		..xlabel "Time (s)"
		..ylabel "Vertical position (degrees)"

	for {id, name, fitter} in algorithms
		fit = fitter(noiseLevel: noiseLevel) ts, measurement
		samplePlot.plot ts, (getDim 0) fit(ts), label: name
			..classed "recon-#{id}"
	samplePlot.show $ '#sample-trial-plot'

	rmse = (x, y) ->
		diffs = sub x, y |> (pow _, 2)
		rse = sum sqrt (add ...nj.transpose diffs)
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

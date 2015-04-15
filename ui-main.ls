$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll, concat} = require 'prelude-ls'
nj = require 'numeric'
{LinInterp, getDim, add, mul, pow, sub, sum, sqrt} = require './vmath.ls'
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

targets =
	* {id: \hybrid, name: "Pursuit and saccade", duration: 2, generator: gazeSimulation.RandomLinearMovementSimulator}
	* {id: \hybrid, name: "Single saccade", duration: 2, generator: gazeSimulation.StepSimulator}

dynamics =
	* id: \bessel, name: "Bessel dynamics", dynamic: gazeSimulation.BesselEyeDynamics
	* id: \trivial, name: "No dynamics", dynamic: -> (x) -> x

$ ->
	$ '#tmp-plot' .hide!
	targetGen = targets[0]
	dynamic = dynamics[1]
	noiseLevel = 0.5
	noiseLevels = [0.1 to 5 by 0.5]
	nIters = 3
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
		d = nj.dim(x)[1] ? 1
		return pow mrse, 1/(d)

	benchmarkOne = (noiseLevel) ->
		{ts, gaze, target, measurement} = simulateTrial noiseLevel
		for algorithm in algorithms
			fitter = algorithm.fitter noiseLevel: noiseLevel
			fit = fitter(ts, measurement) ts
			algorithm: algorithm
			noiseLevel: noiseLevel
			rmse: (rmse fit, target)

	benchmarkNoiseLevel = (noiseLevel) ->
		concat map benchmarkOne, [noiseLevel]*nIters

	benchmark = ->
		concat map benchmarkNoiseLevel, noiseLevels
	
	mrsePlot = mplot.Plot!
		..xlabel "Noise standard deviation (degrees)"
		..ylabel "Root mean square error (degrees)"

	(groupBy (.algorithm), benchmark!).forEach (result, algorithm) ->
		stats = []
		(groupBy (.noiseLevel), result).forEach (r, level) ->
			stats.push [level, sum r.map (.rmse)]
		[x, y] = zipAll ...stats
		mrsePlot.plot x, y, label: algorithm.name
	mrsePlot.show $ \#mrse-plot

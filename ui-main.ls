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
	* id: \greedyOlp, name: "Greedy OLP", fitter: -> GreedyOlp([0.5, 0.5])~fit
	* id: \naiveOlp, name: "Naive OLP", fitter: -> NaiveOlp([0.5, 0.5])~fit

targets =
	* {id: \hybrid, name: "Pursuit and saccade", duration: 2, generator: gazeSimulation.RandomLinearMovementSimulator}
	* {id: \hybrid, name: "Single saccade", duration: 2, generator: gazeSimulation.StepSimulator}

dynamics =
	* id: \bessel, name: "Bessel dynamics"
	* id: \trivial, name: "No dynamics"

$ ->
	$ '#tmp-plot' .hide!
	targetGen = targets[1]
	dynamic = dynamics[0]
	noiseLevel = 0.5
	noiseLevels = [0 to 3 by 0.5]
	nIters = 3
	seed = 0
	Math.random = (new mersennetwister 0)~random

	simulateTrial = (noiseLevel) ->
		sim = gazeSimulation.SignalSimulator do
			target: targetGen.generator!
			duration: targetGen.duration, dt: 0.01
			dynamics: dynamic.dynamic
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
		fit = fitter! ts, measurement
		samplePlot.plot ts, (getDim 0) fit(ts), label: name
			..classed "recon-#{id}"
	samplePlot.show $ '#sample-trial-plot'

	rmse = (x, y) ->
		diffs = sub x, y |> (pow _, 2)
		diff = sum sqrt (add ...nj.transpose diffs)
		return diff/x.length

	benchmarkOne = (noiseLevel) ->
		{ts, gaze, target, measurement} = simulateTrial noiseLevel
		for algorithm in algorithms
			fit = algorithm.fitter!(ts, measurement) ts
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

$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll} = require 'prelude-ls'
{LinInterp, getDim, add, mul} = require './vmath.ls'
{VelocityThreshold, GreedyPiecewiseLinearFit, GreedyOlp, NaiveOlp} = require './segmentation.ls'

require! mersennetwister
seed = undefined
Math.random = (new mersennetwister seed)~random

algorithms =
	* id: \greedyOlp, name: "Greedy OLP", fitter: -> GreedyOlp([0.5, 0.5])~fit
	* id: \naiveOlp, name: "Naive OLP", fitter: -> NaiveOlp([0.5, 0.5])~fit

$ ->
	$ '#tmp-plot' .hide!

	sim = gazeSimulation.SignalSimulator do
		#target: gazeSimulation.StepSimulator!
		duration: 2, dt: 0.01
		dynamics: ((x) -> x)
		noise: gazeSimulation.NdNormNoise [0.5]*2
	{ts, gaze, target, measurement} = sim!
	#ts = [0 til 1 by 0.01]
	#gaze = [[0.0, 0.0]]*ts.length
	#g = mul ts, 0.0
	#gaze = zipAll g, g
	#measurement = map ((x) -> add x, sim.noise.sample!), gaze

	#result = Reconstruct VelocityThreshold!, ts, measurement
	#gols = GreedyOls([0.5, 0.5])
	#for [t, x] in zipAll ts, measurement
	#	gols.measurement t, x
	

	samplePlot = mplot.Plot!
		..plot ts, (getDim 0) gaze
			..classed \gaze-plot, true
		..scatter ts, (getDim 0) measurement
			..classed \measurement-plot, true
		..xlabel "Time (s)"
		..ylabel "Vertical position (degrees)"
	
	for {name, fitter} in algorithms
		fit = fitter! ts, measurement
		samplePlot.plot ts, (getDim 0) fit(ts)

	samplePlot.show $ '#sample-trial'



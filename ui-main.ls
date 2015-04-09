$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll} = require 'prelude-ls'
{LinInterp, getDim, add, mul} = require './vmath.ls'
{VelocityThreshold, PiecewiseLinearFit, Nols} = require './segmentation.ls'

require! mersennetwister
seed = undefined
Math.random = (new mersennetwister seed)~random

$ ->
	$ '#tmp-plot' .hide!

	sim = gazeSimulation.SignalSimulator do
		duration: 1, dt: 0.01
		#dynamics: ((x) -> x)
	{ts, gaze, target, measurement} = sim!

	#ts = [0 til 1 by 0.01]
	#gaze = [[0.0, 0.0]]*ts.length
	#g = mul ts, 0.0
	#gaze = zipAll g, g
	#measurement = map ((x) -> add x, sim.noise.sample!), gaze

	#result = Reconstruct VelocityThreshold!, ts, measurement

	nols = Nols([1.0, 1.0])
	for [t, x] in zipAll ts, measurement
		nols.measurement t, x

	console.log nols.splits!
	result = PiecewiseLinearFit nols.splits!, ts, measurement
	console.log (getDim 0) result(ts)

	mplot.Plot!
		..plot ts, (getDim 0) gaze
			..classed \gaze-plot, true
		..scatter ts, (getDim 0) measurement
			..classed \measurement-plot, true
		..plot ts, (getDim 0) result(ts)
		..show $ '#main-plot'

	speedDist = sim.target.speedDist
	mplot.Plot!
		..plot rng=[0 to 30 by 0.1], speedDist~cdf `map` rng
		..show $ '#tmp-plot'


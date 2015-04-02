$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll} = require 'prelude-ls'
{LinInterp, getDim} = require './vmath.ls'
{VelocityThreshold, Reconstruct} = require './segmentation.ls'

require! mersennetwister
Math.random = (new mersennetwister 0)~random

$ ->
	$ '#tmp-plot' .hide!

	sim = gazeSimulation.SignalSimulator duration: 10
	{ts, gaze, target, measurement} = sim!

	result = Reconstruct VelocityThreshold!, ts, measurement

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


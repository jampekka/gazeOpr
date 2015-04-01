$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll} = require 'prelude-ls'

$ ->
	sim = gazeSimulation.SignalSimulator duration: 10
	{ts, gaze, target, signal} = sim!
	mplot.Plot!
		..plot ts, zipAll(...gaze)[0]
		..scatter ts, zipAll(...signal)[0]
		..show $ '#main-plot'

	speedDist = sim.target.speedDist
	mplot.Plot!
		..plot rng=[0 to 30 by 0.1], speedDist~cdf `map` rng
		..show $ '#tmp-plot'


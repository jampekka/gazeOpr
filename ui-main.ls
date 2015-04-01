$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
{map, zipAll} = require 'prelude-ls'

$ ->
	sim = gazeSimulation.SignalSimulator duration: 10
	{ts, gaze, target} = sim!
	mplot.Plot!
		..plot ts, zipAll(...target)[0]
		..show $ '#main-plot'

	speedDist = sim.target.speedDist
	mplot.Plot!
		..plot rng=[0 to 20 by 0.1], map speedDist~pdf, rng
		..show $ '#tmp-plot'


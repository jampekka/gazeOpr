$ = require \jquery
require! './mplot.ls'
require! './gazeSimulation.ls'
require 'script!jStat/dist/jstat.js'
{map, zipAll} = require 'prelude-ls'

generateSignal = ({dt=0.01, dur=60.0, sim=gazeSimulation.RandomLinearPursuitSimulator!}={}) ->
	for t from 0 to dur by dt
		[t, sim(dt)[0]]

$ ->
	sig = generateSignal!
	[t, xy] = zipAll ...sig
	[x, y] = zipAll ...xy
	fig = new mplot.Plot
	fig.plot t, x
	fig.show $ '#main-plot'


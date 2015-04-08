$ = require \jquery
{map} = require 'prelude-ls'

tests = []
test = (name, tester) -> tests.push [name, tester]

$ ->
	b = $ \body
	for [name, tester] in tests
		b = $ '<test-block>' .appendTo $ \body
		b.append "<test-name>#name</test-name>"
		el = $ '<test-area>' .appendTo b
		tester.apply el

test "mplot", ->
	require! './mplot.ls'

	x = [1,2,3]
	y = [1,2,3]
	mplot.Plot!
		..plot x, y
		..scatter x, y
		..show @

test "Linear fit", ->
	require! './mplot.ls'
	{add, LinearFit} = require './vmath.ls'
	# Probably polluting the namespace :(
	require 'script!jStat/dist/jstat.js'

	x = [0 to 10 by 0.1]
	noiser = -> jStat.normal(0, 1.0).sample!
	noise = map noiser, x
	y = add x, noise

	fit = LinearFit x, y
	console.log fit.coeffs!
	mplot.Plot!
		..scatter x, y
		..plot x, (map fit, x)
		..show @

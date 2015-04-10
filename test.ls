$ = require \jquery
{map} = require 'prelude-ls'

require! \assert
assert.allmostEqual = (a, b, ...args) ->
	# TODO: Relative error
	assert (Math.abs(a - b) < assert.allmostEqual.eps), ...args
assert.allmostEqual.eps = 1e-3

tests = []
test = (name, tester) -> tests.push [name, tester]

$ ->
	b = $ \body
	for [name, tester] in tests
		b = $ '<test-block>' .appendTo $ \body
		b.append "<test-name>#name</test-name>"
		el = $ '<test-area>' .appendTo b
		tester.apply el

test "Linear fit", ->
	require! './mplot.ls'
	{mul, add, pow, LinearFit, sum, sub, div} = require './vmath.ls'
	# Probably polluting the namespace :(
	require 'script!jStat/dist/jstat.js'

	x = [0 to 10 by 0.01]
	noiser = -> jStat.normal(0, 0.0).sample!
	noise = map noiser, x
	slope = 100
	intercept = 100
	y = add intercept, (mul x, slope)
	y = add y, noise

	fit = LinearFit ts: x, xs: y
	fitted = (map fit, x)

	mean = (x) -> sum x |> div _, x.length
	ss = (x, fit=mean x) -> sub x, fit |> pow _, 2 |> sum

	assert.allmostEqual (ss x), fit.t.ss, "X sum of squares"
	assert.allmostEqual (ss y), fit.x.ss, "Y sum of squares"
	assert.allmostEqual fit.coeffs!.0, intercept
	assert.allmostEqual fit.coeffs!.1, slope
	assert.allmostEqual (ss y, fitted), fit.residualSs!, "Residual sum of squares"

	mplot.Plot!
		..scatter x, y
		..plot x, fitted
		..show @

test "Slope fit", ->
	require! './mplot.ls'
	{mul, add, pow, SlopeFit, sum, sub, div} = require './vmath.ls'
	# Probably polluting the namespace :(
	require 'script!jStat/dist/jstat.js'

	x = [0 to 10 by 0.01]
	noiser = -> jStat.normal(0, 0.0).sample!
	noise = map noiser, x
	slope = 100
	intercept = 0
	y = add intercept, (mul x, slope)
	y = add y, noise

	fit = SlopeFit ts: x, xs: y
	fitted = (map fit, x)

	mean = (x) -> sum x |> div _, x.length
	ss = (x, fit=mean x) -> sub x, fit |> pow _, 2 |> sum

	assert.allmostEqual (ss y, fitted), fit.residualSs!, "Residual sum of squares"
	assert.allmostEqual fit.slope!, slope, "Slope estimate"

	mplot.Plot!
		..scatter x, y
		..plot x, fitted
		..show @

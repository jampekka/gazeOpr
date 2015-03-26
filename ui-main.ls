$ = require \jquery
require! "./mplot.ls"

$ ->
	fig = new mplot.Plot
	fig.plot [1,2,3], [1,2,3]
	fig.show $ '#main-plot'


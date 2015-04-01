require! jquery: $
require! d3
plottable = require 'script!plottable.js/plottable.js'
plottable = require 'plottable.js/plottable.css'
require! 'element-resize-event'
{zip, zipObj, map} = require "ramda"
require! './fobj.ls'

export Plot = fobj ->
	@plots = []
	@xScale = new Plottable.Scale.Linear
	@xAxis = new Plottable.Axis.Numeric @xScale, "bottom"
	@yScale = new Plottable.Scale.Linear
	@yAxis = new Plottable.Axis.Numeric @yScale, "left"

	@plot = (x, y) ~>
		plot = new Plottable.Plot.Line @xScale, @yScale
			..addDataset map zipObj([\x,\y], _), zip(x, y)
			..project \x, \x, @xScale
			..project \y, \y, @yScale
		@plots.push plot

	@show = (el) ~>
		plots = new Plottable.Component.Group @plots
		renderer = new Plottable.Component.Table [
			[null, null, null],
			[null, @yAxis, plots],
			[null, null, @xAxis]]

		el.find("svg.mplot-canvas").remove()
		svg = $("<svg class='mplot-canvas'>").appendTo el
		# Every. Single. Time. Getting really bored with these resize hacks.
		# Every time anybody writes writes 'px' or similar to any library,
		# a finger should be cut off.	
		resize = ->
			svg.css width: el.width(), height: el.height()
			renderer.renderTo d3.selectAll svg
		resize()
		elementResizeEvent el[0], resize

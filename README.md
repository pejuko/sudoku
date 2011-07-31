Sudoku generator and solver
---------------------------

Running web demo
================

[http://sudoku-game.heroku.com/](http://sudoku-game.heroku.com)

* play on-line
* print sudoku book


Usage from command line
=======================

Solve sudoku from file:

    sudoku.rb <filename>

Generate new sudoku:

    sudoku.rb <dimension> [level=<1..5>] [alphabet]


API
===

Create new sudoku:

    require 'sudoku'

    level = 3
    dimension = 9
    type = :numeric
    sudoku = Sudoku::Genearator.new level, dimension, type
    sudoku.print_sudoku

Solve sudoku with time limit 60 secods:

    require 'sudoku'

    sudoku = Sudoku::Solver.new Sudoku::Grid.read_file(ARGV[0]), 60
    sudoku.print_result


Solver
======

Solver firstly tries solve a grid with [rules](http://www.sudokudragon.com/sudokustrategy.htm) 
before brute force method. Brute force method can be limited with time.

Implemented rules:

* Only choice rule
* Single possibility rule


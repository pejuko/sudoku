Sudoku generator and solver
---------------------------

Running web demo
================

[http://sudoku-game.heroku.com/](http://sudoku-game.heroku.com)


Usage from command line
=======================

    sudoku.rb <filename>

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

Solve sudoku:

    require 'sudoku'

    sudoku = Sudoku::Solver.new Sudoku::Grid.read_file(ARGV[0])
    sudoku.print_result

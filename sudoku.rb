#require 'unprof'
require 'pp'

$DEBUG_RULES = true if ENV["SUDOKU_DEBUG_RULES"]

module Sudoku

class Cell
  include Comparable

  attr_accessor :x, :y, :value, :set, :sx, :sy

  def initialize(g, x, y, v=nil)
    @grid = g
    @x, @y = x, y
    @value = v || @grid.zero
    @set = []
    @sx, @sy = [@x/@grid.sqsize, @y/@grid.sqsize]
  end

  alias :row :y
  alias :column :x


  def == o
    @x==o.x and @y==o.y and @value==o.value
  end

  def square
    @grid.get_square @x/@grid.sqsize, @y/@grid.sqsize
  end

  def empty?
    @value == @grid.zero
  end

  def clear!
    @value = @grid.zero
  end

  def possible
    @grid.possible(x,y)
  end

  def possible!
    @set = possible.sort_by{rand}
  end

  def eliminate_group! group
    group.each{|cell| cell.set.delete_if{|s| s==@value}}
  end

  def eliminate!
    return if @value == @grid.zero
    eliminate_group! @grid[@y]
    eliminate_group! @grid.get_column(@x)
    eliminate_group! square
  end

  def try(value)
    @grid.try(@x, @y, value)
  end

  def next!
    @value = @set.shift || @grid.zero
  end

  def to_s
    @value.to_s
  end

  def inspect
    "#<#{self.class.name}:0x%x @x=#{@x}, @y=#{@y}, value=#{@value}, @set=#{@set}>" % self.object_id
  end
end


class Grid < Array

  attr_reader :dim, :sqsize, :zero, :chars, :chars_name, :checks

  def self.read_file(fname)
    gr = []
    File.readlines(fname).each do |line|
      line.strip!
      next if line.empty? or line =~ /^#/
      gr << line.split(/\s+/).map{|n| n}
    end

    chars = :numeric
    chars = :alphabet if gr.flatten.map{|n| n.to_i}.uniq.size == 1

    throw "Wrong number of rows #{gr.size}" if gr.size==0 or gr.size!=gr[0].size

    grid = Grid.new gr[0].size, chars
    gr.size.times do |row|
      throw "Wrong number of columns: #{row}x#{gr[row].size}" if gr[row].size!=grid.size
      gr[row].size.times do |col|
        grid[row][col].value = (chars == :numeric) ? gr[row][col].to_i : gr[row][col]
      end
    end

    grid
  end

  def initialize(dim, chars=:numeric)
    @sqsize = Math.sqrt(dim).to_i
    raise "Wrong dimension #{dim}" if @sqsize**2 != dim
    raise "Unknown symbols #{chars}" unless [:numeric, :alphabet].include?(chars)
    @dim = dim

    @checks = 0
    @zero = 0
    @digits = "#{@dim}".size
    @chars_name = chars
    if chars == :alphabet
      @chars = ('a'..(('a'.ord+@dim-1).chr)).to_a
      @zero = '.'
      @digits = 1
    else
      @chars = (1..@dim).to_a
    end

    @mask = Array.new(@dim){Array.new(@dim){true}}
    super(@dim){Array.new(@dim){@zero}}
    each_with_index do |row,y|
      row.each_with_index do |cell,x|
        self[y][x] = Cell.new self, x, y, @zero
      end
    end
  end

  def == o
    return false if @sqsize!=o.sqsize or @dim!=o.dim or @chars_name!=o.chars_name
    each_with_index do |r, ri|
      r.each_with_index do |cell, ci|
        return false unless cell==o[ri][ci]
      end
    end
    true
  end

  def dup
    g = Grid.new @dim, @chars_name
    flatten.each do |cell|
      g[cell.y][cell.x].value = cell.value
    end
    g
  end

  def apply_mask(mask)
    each_with_index do |row,y|
      row.each_with_index do |cell,x|
        cell.clear! unless mask[y][x]
        @mask[y][x] = mask[y][x]
      end
    end
  end

  def empty_cells
    flatten.select{|c| c.empty?}
  end

  def try(x,y,n)
    old = self[y][x].value
    self[y][x].value = n

    sx, sy = [x/@sqsize, y/@sqsize]
    result = (check_row(y) and check_column(x) and check_square(sx,sy))

    self[y][x].value = old
    result
  end

  def possible(x,y)
    res = []
    @chars.each do |i|
      res << i if try(x,y,i)
    end
    res
  end

  def noconflict?
    #return false if self[0][0] == @zero
    @dim.times do |i|
      return false unless check_row(i)
      return false unless check_column(i)
    end
    @sqsize.times do |y|
      @sqsize.times do |x|
        return false unless check_square(x,y)
      end
    end
    true
  end

  def check(cells)
    last = @zero
    @checks += 1
    cells.sort_by{|c|c.value}.each do |c|
      next if c.empty?
      return false if c.value == last
      last = c.value
    end
    true
  end

  def check_row(y)
    check self[y]
  end

  def check_column(x)
    check get_column(x)
  end

  def check_square(x, y)
    check get_square(x,y)
  end

  def get_column(x)
    col = []
    self.size.times do |y|
      col << self[y][x]
    end
    col
  end

  def get_square(x,y)
    sq = []
    row = y*@sqsize
    cell = x*@sqsize
    row.upto(row+@sqsize-1) do |r|
      sq += self[r][cell,3]
    end
    sq
  end

  alias oldprint print
  def print(mask=nil)
    oldprint to_s(mask)
  end

  def save(fname,mask=nil)
    File.open(fname, "w"){|f| f << to_s}
  end

  def to_s(mask=nil)
    str = ""
    0.step(@dim-1,@sqsize) do |y|
      str << "\n" if y!=0
      y.upto(y+@sqsize-1) do |row|
        0.step(@dim-1,@sqsize) do |x|
          nums = self[row][x,@sqsize].map{|c| c.value}
          nums.size.times do |i|
            nums[i] = @zero if mask and not mask[row][x+i]
          end
          template = nums.map{|n| " %#{@digits}s" % (n==0 ? "." : n.to_s)}
          str << template.join << " " 
        end
        str << "\n"
      end
    end
    str
  end

end

class Generator

  attr_reader :grid, :mask, :level

  def initialize(level=0, dim=9, chars=:numeric, limit=1)
    @level = level
    @dim = dim
    @grid = Grid.new @dim, chars
    @mask = Array.new(@dim){Array.new(@dim){true}}
    @time_limit = limit
    generate
    create_mask(level)
  end

  def print_grid
    @grid.print
  end

  def print_sudoku
    @grid.print(@mask)
  end

  private

  def solutions
    g = @grid.dup
    g.apply_mask @mask
    return [] if g.empty_cells.empty?
    s = Solver.new g, @time_limit
    s.find_solutions
  end

  def create_mask(level=0)
    loops = 0
    st = Time.now
    begin
      @mask = Array.new(@dim){Array.new(@dim){true}}
      @dim.times do |y|
        gaps = rand(@grid.sqsize/2) + level;
        (0..(@dim-1)).to_a.sort_by{rand}[0,gaps].each do |i|
          @mask[y][i] = false
        end
      end
      loops += 1
    end while (Time.now-st < @time_limit) and (solutions.size != 1) and (loops<100)
    throw "too difficult" if loops > 100
  end

  def solve(cells, time_limit=-1)
    return true if !cells or cells.empty?

    st = Time.now 
    done = false
    i = cells.size - 1
    #cells[i].possible!
    until done
      if time_limit >= 0
        run_time = Time.now - st
        break if run_time > time_limit
      end
      c = cells[i]
      c.next!
      if c.empty?
        return false if i==0
        i -= 1
      else
        i += 1
        return true if i >= cells.size
        cells[i].possible!
      end
    end
  end

  def generate
    x = y = 0
    cells = []
    @grid.each_with_index do |row,y|
      row.each_with_index do |cell,x|
        cell.possible!
        cells << cell
        solve(cells)
      end
    end
  end

end


class Solver < Generator

  attr_reader :grid, :dim, :difficulty

  def initialize(grid, time_limit=1)
    @grid = grid
    @dim = grid.dim
    @difficulty = 0
    @time_limit = time_limit
#    @solvable = solve_rules || solve_brute_force(time_limit)
#    @diffilulty = 99999999999 unless @solvable
    @solutions = []
  end

  def find_solutions keep=false, tl=@time_limit
    st = Time.now
    empty_cells = @grid.empty_cells
    return [@grid.dup] if empty_cells.empty?

    res = solve_brute_force tl
    while res
      if tl>0 and (Time.now-st) > tl
        @solutions = [] unless keep
        break
      end
      @solutions << @grid.dup
      empty_cells.last.clear!
      res = solve(empty_cells, tl)
    end
    @solutions
  end

  def solve_rules
#    @grid.print
#    puts ""
    #rules = [OnlyChoiseRule, SinglePossibilityRule, SubGroupExclusionRule]
    last = @grid.dim*@grid.dim
    empty_cells=@grid.empty_cells
    empty_cells.each{|cell| cell.possible!}
    while true
      break if last == empty_cells.size
      last = empty_cells.size
      Rule::RULES.each do |klass|
        rule = klass.new(@grid)
        res = rule.solve
        if res
          puts klass.name if $DEBUG_RULES
          @difficulty += rule.difficulty
          @grid.print
          puts "-"*(@grid.dim*2+@grid.sqsize-1)
        end
        empty_cells = @grid.empty_cells
        return true if empty_cells.size==0
      end
    end
    false
  end

  def solve_brute_force(time_limit)
#    puts "Brute Force"
    @difficulty += 10000
    cells = []
    st = Time.now
    run_time = 0
    empty_cells = @grid.empty_cells
    empty_cells.each do |cell|
      if time_limit >= 0
        run_time = Time.now - st
        return false if run_time > time_limit
      end
      cell.possible!
      cells << cell
      solved = solve(cells, time_limit - run_time)
      #throw "This Sudoku is impossible to solve" unless solved
      return false unless solved
    end
    et = Time.now
    true
  end

  alias print_result print_grid
end


class Rule

  RULES = []

  def self.inherited(klass)
    RULES << klass
  end

  attr_reader :difficulty, :loops

  def initialize(grid, d)
    @grid = grid
    @difficulty = d
    @loops = 0
  end

end


##
# only one cell left empty in group (row, column, square)
#
class OnlyChoiseRule < Rule
  def initialize(grid, d=1)
    super
  end

  def solve
#    while true
#      return true if @grid.empty_cells.empty?
#      @loops += 1
      res = solve_rows | solve_columns | solve_squares
#      break unless res
#    end
#    false
  end

  private

  def solve_group(cells)
    empty_cells = cells.select{|c| c.empty?}
    return false if empty_cells.empty?
    if empty_cells.size == 1
      empty_cells[0].next!
      empty_cells[0].set = []
      empty_cells[0].eliminate!
      return true
    end
    false
  end

  def solve_rows
    res = false
    @grid.each_with_index do |row,y|
      res |= solve_group(row)
    end
    res
  end

  def solve_columns
    res = false
    @grid.dim.times do |x|
      column = @grid.get_column(x)
      res |= solve_group(column)
    end
    res
  end

  def solve_squares
    res = false
    @grid.sqsize.times do |y|
      @grid.sqsize.times do |x|
        square = @grid.get_square(x,y)
=begin
        square.size.times do |i|
          gy = (y*@grid.sqsize) + (i / @grid.sqsize)
          gx = (x*@grid.sqsize) + (i % @grid.sqsize)
          square[i] = Cell.new(@grid, gx, gy)
        end
=end
        res |= solve_group(square)
      end
    end
    res
  end

end


##
# (slicing and slotting)
# from 1 to 9 check two columns and rows out of three and if the number
# is present in all four groups only one cell left where it must be
#
class TwoOutOfThreeRule < Rule

  def initialize(grid, d=2)
    super
  end

  def solve
    res = false
    empty_cells = @grid.empty_cells
    empty_cells.each do |cell|
      r1=r2=c1=c2=nil
      if (cell.row % @grid.sqsize) == 0
        r1 = @grid[cell.row+1]
        r2 = @grid[cell.row+2]
      elsif (cell.row % @grid.sqsize) == (@grid.sqsize - 1)
        r1 = @grid[cell.row-1]
        r2 = @grid[cell.row-2]
      else
        r1 = @grid[cell.row-1]
        r2 = @grid[cell.row+1]
      end
      if (cell.column % @grid.sqsize) == 0
        c1 = @grid.get_column cell.column+1
        c2 = @grid.get_column cell.column+2
      elsif (cell.column % @grid.sqsize) == (@grid.sqsize - 1)
        c1 = @grid.get_column cell.column-1
        c2 = @grid.get_column cell.column-2
      else
        c1 = @grid.get_column cell.column-1
        c2 = @grid.get_column cell.column+1
      end
      square = cell.square.map{|sq| sq.value}
      @grid.chars.select{|ch| not square.include?(ch)}.each do |n|
        exists = true
        [r1,r2,c1,c2].each do |g|
          if g.select{|c| c.value == n}.empty?
            exists = false
            break
          end
        end
        if exists
          cell.value = n
          cell.eliminate!
          res = true
          break
        end
      end
    end
    res
  end

end


##
# other squares already contains particular number so it must
# be in this one in given row or column (others in this square
# can be eliminated)
# -- this implementation does not eliminate but fill in if there
#    is only possibility for row or column for given number
#    (this differ from Only Choice as it depends on a symbol instead
#     of on number of empty cells)
class OnlySquareRule < Rule

  def initialize(grid, d=3)
    super
  end

  def solve_group group
    res = false
    empty_cells = group.select{|cell| cell.empty?}
    return false if empty_cells.empty?
    @grid.chars.each do |ch|
      next unless group.select{|c| c.value==ch}.empty?
      if (possible_cells=empty_cells.select{|cell| cell.set.include?(ch)}).size==1
        res = true
        possible_cells[0].value = ch
        possible_cells[0].eliminate!
      end
    end
    res
  end

  def solve
    res = false
    @grid.each_with_index do |row, ri|
      res ||= solve_group row
=begin
      squares = []
      @grid.sqsize.times{|si| squares << r[si,@grid.sqsize]}
      @grid.chars.each do |ch|
        next unless r.select{|c| c.value==ch}.empty?
        possible_squares = []
        squares.each_with_index do |rsq, rsi|
          rsq.each do |cell|
            possible_squares << [rsi, cell] if cell.set.include?(ch)
          end
        end
        if possible_squares.size==1
          possible_squares[0][1].value = ch
          res = true
        end
      end
=end
    end
    @grid.sqsize.times do |c|
      col = @grid.get_column c
      res ||= solve_group col
    end
    res
  end

end


##
# single possibility for one cell
#
class SinglePossibilityRule < Rule

  def initialize(grid, d=4)
    super
  end
 
  def solve
    res = false
    empty_cells = @grid.empty_cells
    return false if empty_cells.empty?
    empty_cells.sort_by!{|c| c.set.size}
    return false if empty_cells.first.set.size>1
    while empty_cells.size>0 and empty_cells[0].set.size==1
      res = true
      c = empty_cells.shift
      c.next!
      c.eliminate!
    end
    res
  end
end


##
# if a possible number can be only in one row or column we can exclude
# this number from other possibilities in other squares for this row/column.
# (reduce the search space)
#
class SubGroupExclusionRule < Rule

  def initialize(grid, d=10)
    super
  end

  def solve
    res = false
    @grid.sqsize.times do |sr|
      @grid.sqsize.times do |sc|
        square = @grid.get_square(sc,sr)
        empty_cells = square.select{|cell| cell.empty?}
        @grid.chars.each do |ch|
          chcells = empty_cells.select{|cell| cell.set.include?(ch)}
          next if chcells.empty?
          rch = chcells.select{|cell| cell.row==chcells.first.row}
          cch = chcells.select{|cell| cell.column==chcells.first.column}
          if rch.size == chcells.size
            res ||= eliminate_group ch, @grid[rch.first.y], sc, sr
          end
          if cch == chcells.size
            res ||= eliminate_group ch, @grid.get_column(cch.first.x), sc, sr
          end
        end
      end
    end
    res
  end

  private

  # eliminates possibilities in group except cells in square sx, sy
  def eliminate_group ch, group, sx, sy
    res = false
    group.each do |cell|
      next if cell.sx==sx and cell.sy==sy
      if cell.set.include?(ch)
        #pp [ch, sx, sy, cell]
        cell.set.delete_if{|a| a==ch}
        res = true
      end
    end
    res
  end

end


##
# (triplet exclusion rule)
# if there are two same pairs of numbers in two different squares and none 
# of them is possible elsewhere it is possible to exclude other possibilities
#
class HiddenTwinExclusionRule < Rule

  def initialize(grid, d=11)
    super
  end

  def solve
    false
  end

end


##
# if there are two cells with two same numbers possible and not anything else
# then in those cells must be those two numbers and they can be excluded from
# other cells possibilities
#
class NakedTwinExclusionRule < Rule

  def initialize(grid, d=12)
    super
  end

  def solve
    res = false
    empty_cells = @grid.empty_cells.select{|cell| cell.set.size==2}
    while not empty_cells.empty?
      cell = empty_cells.shift
      twins = [cell]
      empty_cells.each do |c|
        twins << c if c.set.include?(cell.set[0]) and c.set.include?(cell.set[1]) and c.sx==cell.sx and c.sy==cell.sy
      end
      square = @grid.get_square(cell.sx, cell.sy)
      v1 = square.select{|c| c.set.include?(cell.set[0])}
      v2 = square.select{|c| c.set.include?(cell.set[1])}
      if twins.size==2 and v1.size==2 and v2.size==2
        square.each do |sqc|
          next if twins.include?(sqc)
          sqc.set.each do |a|
            if cell.set.include?(a)
              sqc.set.delete_if{|a| cell.set.include?(a)}
              res = true
            end
          end
        end
      end
    end
    res
  end

end


##
# if a number possibilities accross whole grid form a corners of a box
# and they are only two possible locations on row/column then possibilities
# in other column/row cells can be excluded
#
class XWingRule < Rule

  def initialize(grid, d=100)
    super
  end

  def solve
    false
  end

end


##
# similar to xwing but one corner of the box is extended and is also corner
# of another box:
#
#         1       1
#
#
#  1      +       1
#
#  1      1
#
# other one's possibilities can be excluded (except those six) in six different
# squares
#
class SwordFishRule < Rule

  def initialize(grid, d=110)
    super
  end

  def solve
    false
  end

end

end



if __FILE__ == $0

  level = 2
  dim = 9
  chars = :numeric
  file_name = nil

  if ARGV.size != 0
    if ARGV.size==1 and File.exist?(ARGV[0])
      file_name = ARGV[0]
      s = Sudoku::Solver.new Sudoku::Grid.read_file(ARGV[0])
      solvable = s.solve_rules
      solvable ||= s.solve_brute_force 60
      s.print_result
      puts "checks: #{s.grid.checks}"
      puts "difficulty: #{s.difficulty}"
      puts "solvable: #{solvable}"
      #s.grid.save(ARGV[0]+'.result')
    elsif File.exist? ARGV[0]
      file_name = ARGV[0]
      tl = (ARGV[1] || -1).to_i
      s = Sudoku::Solver.new Sudoku::Grid.read_file(ARGV[0]), tl
      st = Time.now
      solutions = s.find_solutions(true)
      et = Time.now
      solutions.each { |s| s.print; puts "-"*20 }
      puts "solutions: #{solutions.size}"
      puts "time: #{et-st}"
    else
      dim = ARGV.shift.to_i
      level = ARGV.shift.to_i if ARGV.size > 0
      chars = ARGV.shift.to_sym if ARGV.size > 0
      s = Sudoku::Generator.new level, dim, chars
      s.print_sudoku
    end
  else
    puts <<-EOF
    #{File.basename $0} <filename>
    #{File.basename $0} <filename> <timelimit (0==off, -1==inf)>
    #{File.basename $0} <dimension> [level from <1..5>] [alphabet]
    EOF
  end

end

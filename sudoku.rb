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

  attr_reader :dim, :sqsize, :zero, :chars, :chars_name, :checks, :mask

  def self.read_file(fname)
    gr = []
    File.readlines(fname).each do |line|
      line.strip!
      next if line.empty? or line =~ /^#/
      gr << line.split(/\s+/).map{|n| n}
    end

    # handle one line format
    if gr.size==1 and gr[0].size==1
      line = gr[0][0].split(//)
      dim = Math.sqrt(line.size).to_i
      throw "Wrong dimension" if dim*dim != line.size
      gr = []
      line.each_slice(dim){|sl| gr << sl}
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

  def num_cells
    @dim*@dim
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

  def get_row(y)
    self[y]
  end

  def get_column(x)
    col = []
    self.size.times do |y|
      col << self[y][x]
    end
    col
  end

  def get_columns
    columns = []
    @dim.times do |x|
      columns << get_column(x)
    end
    columns
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

  #DIFFICULTY = [30, 50, 80, 110, 140, 170, 200, 250, 300, 400]
  DIFFICULTY = [20, 30, 60, 120, 250, 500, 1000, 1500, 2000, 5000]

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

  def solvable?
    g = @grid.dup
    g.apply_mask @mask
    return false if g.empty_cells.empty?
    s = Solver.new g, @time_limit
    return s if s.solve_rules
    false
  end

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
    et = st
    s = true
    #@mask = Array.new(@dim){Array.new(@dim){(rand(@grid.num_cells/2) % @grid.dim == 0) ? false : true}}
    @mask = Array.new(@dim){Array.new(@dim){true}}
    sold_mask = @mask.dup
    cells = []
    @mask.each_with_index{|r,ri| r.each_with_index {|c,ci| cells << [ri, ci]}}
    cells.sort_by!{rand}
    unused = []
    used = []
    y, x = -1, -1
    strongest = nil
    closest = nil
    begin
      loops += 1
      y, x = cells.shift
      @mask[y][x] = false
      sold = s
      s = solvable?
      unless s
        @mask[y][x] = true
        s = sold
        unused << [y,x]
      else
        strongest = s if not strongest or strongest.difficulty < s.difficulty
        closest = s if not closest or (closest.difficulty-DIFFICULTY[level]).abs > (s.difficulty-DIFFICULTY[level]).abs
        used << [y,x]
      end
      if cells.empty?
        cells = unused.sort_by{rand}
        u = used.shift
        @mask[u[0]][u[1]] = true
        cells << u
        unused = []
      end
      et = Time.now
    end while (et-st < @time_limit) and (closest and closest.difficulty < DIFFICULTY[level])# and (loops<100)
    p [et-st, loops, DIFFICULTY[level]]
    p closest.difficulty
    p closest.used_rules
    @mask = closest.grid.mask
#    throw "too difficult" if loops >= 100 or et-st>=@time_limit
#    throw "too difficult" if et-st>=@time_limit
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

  attr_reader :grid, :dim, :difficulty, :used_rules

  def initialize(grid, time_limit=1)
    @grid = grid
    @dim = grid.dim
    @difficulty = 0
    @time_limit = time_limit
#    @solvable = solve_rules || solve_brute_force(time_limit)
#    @diffilulty = 99999999999 unless @solvable
    @solutions = []
    @used_rules = []
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
    found = false
    while true
      break if last == empty_cells.size and not found
      found = false
      last = empty_cells.size
      Rule::RULES.each do |klass|
      #[SwordFishRule].each do |klass|
        rule = klass.new(@grid)
        res = rule.solve
        found ||= res
        empty_cells = @grid.empty_cells
        if res
          @difficulty += rule.difficulty
          @used_rules << klass
          if $DEBUG_RULES
            puts klass.name
            @grid.print
            puts "-"*(@grid.dim*2+@grid.sqsize-1)
          end
          break
        end
      end
      return true if empty_cells.size==0
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
# (full house)
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
class OnlySquareRule < Rule

  def initialize(grid, d=5)
    super
  end

  def solve_group group
    res = false
    empty_cells = group.select{|cell| cell.empty?}
    return false if empty_cells.empty?
    @grid.chars.each do |ch|
      next unless group.select{|c| c.value==ch}.empty?
      possible_cells=empty_cells.select{|cell| cell.set.include?(ch)}
      next if possible_cells.empty?
      if possible_cells.select{|cell| cell.sx==possible_cells[0].sx and cell.sy==possible_cells[0].sy}.size==possible_cells.size
        #pp possible_cells
        square = possible_cells[0].square
        square.each do |cell|
          next if possible_cells.include?(cell)
          next if not cell.set.include?(ch)
          #pp cell
          res = true
          cell.set.delete_if{|a| a==ch}
        end
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
# (naked single)
# single possibility for one cell
#
class SinglePossibilityRule < Rule

  def initialize(grid, d=30)
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
# hidden single
# it is only choice in one group in other group there can be possibilities
class HiddenSingleRule < OnlyChoiseRule

  def initialize(grid, d=40)
    super
  end

  def solve_group cells
    res = false
    empty_cells = cells.select{|cell| cell.empty?}
    @grid.chars.each do |ch|
      chcells = empty_cells.select{|cell| cell.set.include?(ch)}
      if chcells.size==1
        res = true
        chcells[0].value = ch
        chcells[0].set.delete_if{|s| s==ch}
        chcells[0].eliminate!
      end
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

  def initialize(grid, d=40)
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
class HiddenTwinExclusionRule < OnlyChoiseRule

  def initialize(grid, d=55)
    super
  end

  def solve_group cells
    res = false
    empty_cells = cells.select{|cell| cell.empty? and cell.set.size >= 2}
    empty_cells.each do |cell|
      cell.set.each do |a|
        cell.set.each do |b|
          next if a==b
          twins = empty_cells.select{|c| c.set.include?(a) and c.set.include?(b)}
          ac = cells.select{|c| c.empty? and c.set.include?(a)}
          bc = cells.select{|c| c.empty? and c.set.include?(b)}
          if twins.size==2 and ac.size==2 and bc.size==2
            twins.each do |tc|
              if (tc.set.size > 2)
                #pp twins
                #pp tc
                tc.set.delete_if{|x| x!=a and x!=b}
                #pp tc
                res = true
              end
            end
          end
        end
      end
    end
    res
  end

end


##
# if there are two cells with two same numbers possible in same group and not
# anything else then in those cells must be those two numbers and they can be
# excluded from other cells possibilities in the same group
#
class NakedTwinExclusionRule < OnlyChoiseRule

  def initialize(grid, d=50)
    super
  end

  def solve_group cells
    res = false
    empty_cells = cells.select{|cell| cell.empty? and cell.set.size==2}
    empty_cells.each do |cell|
      twins = empty_cells.select { |c| c.set.include?(cell.set[0]) and c.set.include?(cell.set[1]) }
      if twins.size==2
        cells.each do |ec|
          next if not ec.empty?
          next if twins.include?(ec)
          if ec.set.include?(cell.set[0]) or ec.set.include?(cell.set[1])
            #pp twins
            #pp ec
            ec.set.delete_if{|a| cell.set.include?(a)}
            #pp ec
            res = true
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

  def initialize(grid, d=500)
    super
  end

  def solve
    res = false
    res ||= solve_rows | solve_columns
    res
  end

  def solve_rows
    res = false
    candidates = []
    @grid.each_with_index do |row,ri|
      @grid.chars.each do |ch|
        cells = row.select{|c| c.empty? and c.set.include?(ch)}
        candidates << [ch, cells.sort{|a,b| a.sx<=>b.sx}] if cells.size==2
      end
    end
    candidates.each do |cand|
      corners = candidates.select{|c| c[0]==cand[0] and c[1][0].x==cand[1][0].x and c[1][1].x==cand[1][1].x}
      if corners.size==2
        cells = corners.map{|x| x[1]}.flatten
        #pp cells
        cols = cells.map{|c| c.x}.uniq
        cols.each do |col|
          @grid.get_column(col).each do |c|
            next if cells.include?(c)
            if c.set.include?(cand[0])
              #pp c
              c.set.delete_if{|x| x==cand[0]}
              res = true
            end
          end
        end
      end
    end
    res
  end


  def solve_columns
    res = false
    candidates = []
    @grid.get_columns.each_with_index do |column,ci|
      @grid.chars.each do |ch|
        cells = column.select{|c| c.empty? and c.set.include?(ch)}
        candidates << [ch, cells.sort{|a,b| a.sy<=>b.sy}] if cells.size==2
      end
    end
    #pp candidates
    candidates.each do |cand|
      corners = candidates.select{|c| c[0]==cand[0] and c[1][0].y==cand[1][0].y and c[1][1].y==cand[1][1].y}
      if corners.size==2
        cells = corners.map{|x| x[1]}.flatten
        #pp cells
        rows = cells.map{|c| c.y}.uniq
        rows.each do |row|
          @grid[row].each do |c|
            next if cells.include?(c)
            if c.set.include?(cand[0])
              #pp c
              c.set.delete_if{|x| x==cand[0]}
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

  def initialize(grid, d=600)
    super
  end

  def solve
    res = false
    res ||= solve_rows | solve_columns
    res
  end

  def solve_rows
    res = false
    candidates = []
    @grid.each_with_index do |row,ri|
      @grid.chars.each do |ch|
        cells = row.select{|c| c.empty? and c.set.include?(ch)}
        candidates << [ch, cells.sort{|a,b| a.x<=>b.x}] if cells.size==2
      end
    end
    #pp candidates
    candidates.each do |cand|
      corner1 = candidates.select{|c|
        c[0]==cand[0] and cand[1][0].x==c[1][1].x and cand[1][1].x!=c[1][0].x
      }
      corner2 = candidates.select{|c|
        c[0]==cand[0] and cand[1][0].x!=c[1][1].x and cand[1][1].x==c[1][1].x
      }
      corners = ([cand] | corner1 | corner2).map{|y| y[1]}.sort{|a,b| a[0].y<=>b[0].y}
      cells = corners.flatten
      next if corners.size != 3 or cells.size != 6
      next if not ( (corners[1][0].x == corners[2][0].x and corners[1][1].x == corners[0][1].x) or
                    (corners[1][0].x == corners[0][0].x and corners[1][1].x == corners[2][1].x) )
      res |= eliminate( cand[0], corners, cells, :column)
    end
    res
  end

  def solve_columns
    res = false
    candidates = []
    @grid.get_columns.each_with_index do |column,ci|
      @grid.chars.each do |ch|
        cells = column.select{|c| c.empty? and c.set.include?(ch)}
        #cells.delete_if{|c| cells.select{|c2| c2.sy==c.sy}.size > 1}
        candidates << [ch, cells.sort{|a,b| a.y<=>b.y}] if cells.size==2
      end
    end
    #pp candidates
    candidates.each do |cand|
      corner1 = candidates.select{|c|
        c[0]==cand[0] and cand[1][0].y==c[1][1].y and cand[1][1].y!=c[1][0].y
      }
      corner2 = candidates.select{|c|
        c[0]==cand[0] and cand[1][0].y!=c[1][1].y and cand[1][1].y==c[1][1].y
      }
      corners = ([cand] | corner1 | corner2).map{|x| x[1]}.sort{|a,b| a[0].x<=>b[0].x}
      cells = corners.flatten
      next if corners.size != 3 or cells.size != 6
      next if not ( (corners[1][0].y == corners[2][0].y and corners[1][1].y == corners[0][1].y) or
                    (corners[1][0].y == corners[0][0].y and corners[1][1].y == corners[2][1].y) )
      res |= eliminate( cand[0], corners, cells, :row )
    end
    res
  end

  def eliminate cand, corners, cells, dir
    res=false
    #pp corners
    #pp cells
    rows = cells.map{|c| c.send(dir)}.uniq
    rows.each do |row|
      @grid.send("get_#{dir}", row).each do |c|
        next if cells.include?(c)
        if c.set.include?(cand) and c.set.size>1
          c.set.delete_if{|x| x==cand}
          #pp [cand, dir, c]
          res = true
        end
      end
    end
    res
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
      time_limit = (ARGV.shift || 10).to_f
      s = Sudoku::Generator.new level, dim, chars, time_limit
      s.print_sudoku
    end
  else
    puts <<-EOF
    #{File.basename $0} <filename>
    #{File.basename $0} <filename> <timelimit (0==off, -1==inf)>
    #{File.basename $0} <dimension> [level from <0..9>] [alphabet|numeric] [time limit]
    EOF
  end

end

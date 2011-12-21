#require 'unprof'
require 'pp'

module Sudoku

class Cell
  attr_accessor :x, :y, :value, :set

  def initialize(g, x, y, v=nil)
    @grid = g
    @x, @y = x, y
    @value = v || @grid.zero
    @set = []
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

  attr_reader :dim, :sqsize, :zero, :chars, :checks

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

  def initialize(level=0, dim=9, chars=:numeric)
    @level = level
    @dim = dim
    @grid = Grid.new @dim, chars
    @mask = Array.new(@dim){Array.new(@dim){true}}
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

  # TODO: find all solutions if more then one
  def solutions
    g = @grid.dup
    g.apply_mask @mask
    s = Solver.new g
    s.find_solutions
  end

  def create_mask(level=0)
    loops = 0
    begin
      @mask = Array.new(@dim){Array.new(@dim){true}}
      @dim.times do |y|
        gaps = rand(@grid.sqsize/2) + level;
        (0..(@dim-1)).to_a.sort_by{rand}[0,gaps].each do |i|
          @mask[y][i] = false
        end
      end
      loops += 1
    end while (solutions.size != 1) or (loops > 100)
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

  def initialize(grid, time_limit=60)
    @grid = grid
    @dim = grid.dim
    @difficulty = 0
    @time_limit = time_limit
#    @solvable = solve_rules || solve_brute_force(time_limit)
#    @diffilulty = 99999999999 unless @solvable
    @solutions = []
  end

  def find_solutions
    empty_cells = @grid.empty_cells
    res = solve_brute_force @time_limit
    while res
      @solutions << @grid.dup
      empty_cells.last.clear!
      res = solve(empty_cells, @time_limit)
    end
    @solutions
  end

  def solve_rules
#    @grid.print
#    puts ""
    #rules = [OnlyChoiseRule, SinglePossibilityRule, SubGroupExclusionRule]
    last = 81
    empty_cells=@grid.empty_cells
    while true
      break if last == empty_cells.size
      last = empty_cells.size
      Rule::RULES.each do |klass|
        rule = klass.new(@grid)
        res = rule.solve
        puts klass.name if res
        @difficulty += rule.difficulty if res
#        @grid.print
#        puts "---"
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
    empty_cells = []
    cells.each{|c| empty_cells << c if c.empty?}
    return false if empty_cells.empty?
    if empty_cells.size == 1
      empty_cells[0].possible!
      empty_cells[0].next!
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


class SinglePossibilityRule < Rule

  def initialize(grid, d=2)
    super
  end
 
  def solve
    res = false
    empty_cells = @grid.empty_cells
    return false if empty_cells.empty?
    empty_cells.each{|c| c.possible!}
    empty_cells.sort_by!{|c| c.set.size}
    return false if empty_cells.first.set.size>1
    while empty_cells.size>0 and empty_cells[0].set.size==1
      res = true
      c = empty_cells.shift
      c.next!
    end
    res
  end
end


class OnlySquareRule < Rule

  def initialize(grid, d=3)
    super
  end

  def solve
    false
  end

end


class TwoOutOfThreeRule < Rule

  def initialize(grid, d=3)
    super
  end

  def solve
    false
  end

end


class SubGroupExclusionRule < Rule

  def initialize(grid, d=10)
    super
  end

  def solve
    false
  end

end


class HiddenTwinExclusionRule < Rule

  def initialize(grid, d=11)
    super
  end

  def solve
    false
  end

end


class NakedTwinExclusionRule < Rule

  def initialize(grid, d=12)
    super
  end

  def solve
    false
  end

end


class XWingRule < Rule

  def initialize(grid, d=100)
    super
  end

  def solve
    false
  end

end


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
      s.find_solutions.each { |s| s.print; puts "-"*20 }
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

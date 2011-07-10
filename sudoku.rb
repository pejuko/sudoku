#require 'unprof'
#require 'pp'

module Sudoku

class Cell
  attr_accessor :x, :y, :set

  def initialize(g, x, y)
    @grid = g
    @x, @y = x, y
  end

  def empty?
    @grid[y][x] == @grid.zero
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

  def value 
    @grid[y][x]
  end

  def value=(value)
    @grid[y][x] = value
  end

  def next!
    @grid[y][x] = @set.shift || @grid.zero
  end

  def inspect
    "#<#{self.class.name}:0x%x @x=#{@x}, @y=#{@y}, value=#{value}, @set=#{@set}>" % self.object_id
  end
end


class Grid < Array

  attr_reader :dim, :sqsize, :zero, :chars

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
        grid[row][col] = (chars == :numeric) ? gr[row][col].to_i : gr[row][col]
      end
    end

    grid
  end

  def initialize(dim, chars=:numeric)
    @sqsize = Math.sqrt(dim).to_i
    raise "Wrong dimension #{dim}" if @sqsize**2 != dim
    @dim = dim

    @zero = 0
    @digits = "#{@dim}".size
    if chars == :alphabet
      @chars = ('a'..(('a'.ord+@dim-1).chr)).to_a
      @zero = '.'
      @digits = 1
    else
      @chars = (1..@dim).to_a
    end

    super(@dim){Array.new(@dim){@zero}}
  end

  def empty_cells
    cells=[]
    @dim.times do |y|
      @dim.times do |x|
        cells << Cell.new(self,x,y) if self[y][x] == @zero
      end
    end
    cells
  end

  def try(x,y,n)
    old = self[y][x]
    self[y][x] = n

    sx, sy = [x/@sqsize, y/@sqsize]
    result = (check_row(y) and check_column(x) and check_square(sx,sy))

    self[y][x] = old
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

  def check(numbers)
    last = @zero
    numbers.sort.each do |n|
      next if n == @zero
      return false if n == last
      last = n
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
          nums = self[row][x,@sqsize]
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
    1
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
    end while (solutions != 1) or (loops > 100)
    throw "too difficult" if loops > 100
  end

  def solve(cells)
    return true if !cells or cells.empty?

    done = false
    i = cells.size - 1
    cells[i].possible!
    until done
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
    @dim.times do |y|
      @dim.times do |x|
        cells << Cell.new(@grid, x, y)
        solve(cells)
      end
    end
  end

end

class Solver < Generator

  attr_reader :grid, :dim

  def initialize(grid)
    @grid = grid
    @dim = grid.dim
    cells = []
    @grid.empty_cells.each do |cell|
      cells << cell
      solved = solve(cells)
      throw "This Sudoku is impossible to solve" unless solved
    end
  end

  alias print_result print_grid
end

end



if __FILE__ == $0

  level = 2
  dim = 9
  chars = :numeric
  file_name = nil

  if ARGV.size != 0
    if File.exist? ARGV[0]
      file_name = ARGV[0]
      s = Sudoku::Solver.new Sudoku::Grid.read_file(ARGV[0])
      s.print_result
      #s.grid.save(ARGV[0]+'.result')
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
    #{File.basename $0} <dimension> [level=<1..5>] [alphabet]
    EOF
  end

end

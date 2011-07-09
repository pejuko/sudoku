#require 'unprof'
#require 'pp'

module Sudoku

class Cell
  attr_accessor :x, :y, :set

  def initialize(g, x, y)
    @grid = g
    @x, @y = x, y
    posible!
  end

  def empty?
    @grid[y][x] == 0
  end

  def posible
    @grid.posible(x,y)
  end

  def posible!
    @set = posible.sort_by{rand}
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
    @grid[y][x] = @set.shift.to_i
  end

  def inspect
    "#<#{self.class.name}:0x%x @x=#{@x}, @y=#{@y}, value=#{value}, @set=#{@set}>" % self.object_id
  end
end


class Grid < Array

  attr_reader :dim, :sqsize, :digits

  def initialize(dim)
    @sqsize = Math.sqrt(dim).to_i
    raise "Wrong dimension #{dim}" if @sqsize**2 != dim
    @dim = dim
    super(@dim){Array.new(@dim){0}}
    @digits = "#{@dim}".size
  end

  def place(x,y,n)
    old = self[y][x]
    self[y][x] = n
    return true if conflict?
    self[y][x] = old
    false
  end

  def try(x,y,n)
    old = self[y][x]
    self[y][x] = n
    s = conflict?
    self[y][x] = old
    s
  end

  def posible(x,y)
    res = []
    (1..@dim).each do |i|
      res << i if try(x,y,i)
    end
    res
  end

  def conflict?
    return false if self[0][0] == 0
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
    last = 0
    numbers.sort.each do |n|
      next if n == 0
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
#    throw "wrong square number #{x}x#{y}" if x>2 or y>2
    sq = []
    row = y*@sqsize
    cell = x*@sqsize
    (row).upto(row+@sqsize-1) do |r|
      (cell).upto(cell+@sqsize-1) do |c|
        sq << self[r][c]
      end
    end
    sq
  end

  alias oldprint print
  def print(mask=nil)
    0.step(@dim-1,@sqsize) do |y|
      y.upto(y+@sqsize-1) do |row|
        0.step(@dim-1,@sqsize) do |x|
          nums = self[row][x,@sqsize]
          nums.size.times do |i|
            nums[i] = 0 if mask and not mask[row][x+i]
          end
          template = " %#{@digits}d"*@sqsize + " "
          oldprint( template % nums )
        end
        puts "\n"
      end
      puts "\n"
    end
  end

end

class Sudoku

  attr_reader :grid, :mask, :level

  def initialize(level=0, dim=9)
    @level = level
    @dim = dim
    @grid = Grid.new @dim
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
    until done
      c = cells[i]
      c.next!
      if c.empty?
        return false if i==0
        i -= 1
      else
        i += 1
        return true if i >= cells.size
        cells[i].posible!
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

end

dim = ARGV[0] || 9
s = Sudoku::Sudoku.new 2, dim.to_i
#s.print_grid
s.print_sudoku

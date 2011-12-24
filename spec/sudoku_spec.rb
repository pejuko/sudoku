require './sudoku'


def read_grid name
  Sudoku::Grid.read_file "test/#{name}.sud"
end

def read_solver name
  Sudoku::Solver.new read_grid(name)
end

def get_sud name
    sud = read_solver name
    sol = Sudoku::Grid.read_file "test/#{name}_result.sud"
    [sud, sol]
end


describe Sudoku::Solver do

  describe "#solve_rules" do
    ["easy", "medium", "difficult"].each do |name|
      it "test/#{name}.sud" do
        sud, sol = get_sud(name)
        solvable = sud.solve_rules
        solvable.should == true
        sud.grid.should == sol
      end
    end
  end


  describe "#solve_brute_force" do
    ["easy", "medium", "difficult"].each do |name|
      it "test/#{name}.sud" do
        sud, sol = get_sud(name)
        solvable = sud.solve_brute_force 5
        solvable.should == true
        sud.grid.should == sol
      end
    end
  end


  describe "#find_solutions" do
    it "test/multiple_solutions.sud" do
      sud = read_solver "multiple_solutions"
      solutions = sud.find_solutions
      solutions.should have(5).items
    end

    ["easy", "medium", "difficult"].each do |name|
      it "test/#{name}.sud" do
        sud = read_solver name
        solutions = sud.find_solutions
        solutions.should have(1).item
      end
    end

    it "test/impossible.sud" do
      sud = Sudoku::Solver.new Sudoku::Grid.read_file("test/impossible.sud"), 5
      solutions = sud.find_solutions true
      solutions.should be_empty
    end
  end

end


describe Sudoku::Generator do
  (1..5).each do |level|
    it "level #{level}: should generate new grid with only one possible solution" do
      sud = Sudoku::Generator.new level
      solver = Sudoku::Solver.new sud.grid, 5
      solutions = solver.find_solutions true
      solutions.should have(1).item
    end
  end

  (1..5).each do |level|
    it "level #{level}: should have some empty cells" do
      sud = Sudoku::Generator.new level
      sud.grid.apply_mask sud.mask
      sud.grid.empty_cells.should have_at_least(1).item
    end
  end
end


describe Sudoku::Grid do

  before(:each) do
    @grid = Sudoku::Grid.new 9
    @grid.each{|r| r.each{|c| c.value = rand(9)+1}}
  end

  describe "Grid.read_file" do
    it "should be numeric" do
      grid = Sudoku::Grid.read_file "test/easy.sud"
      grid.chars_name.should == :numeric
    end

    it "should be alphabet" do
      grid = Sudoku::Grid.read_file "test/level_3-alphabet.sud"
      grid.chars_name.should == :alphabet
    end

    it "should be solved" do
      grid = Sudoku::Grid.read_file "test/easy_result.sud"
      grid.empty_cells.should be_empty
    end

    it "should be unsolved" do
      grid = Sudoku::Grid.read_file "test/easy.sud"
      grid.empty_cells.should have(47).items
    end
  end

  describe "#initialize" do
    [4, 9, 16, 25].each do |dim|
      it "should have dimension #{dim}" do
        grid = Sudoku::Grid.new dim
        grid.dim.should == dim
        grid.size.should == dim
        grid[0].size.should == dim
      end
    end

    [2, 3, 5, 8].each do |dim|
      it "should fail with dimension #{dim}" do
        expect { Sudoku::Grid.new dim }.to raise_error
      end
    end

    it "should fail with wrong characters" do
      expect { Sudoku::Grid.new 9, :abcdefgh }.to raise_error
    end

    it "should be initialized to 0 for :numeric grid" do
      grid = Sudoku::Grid.new 9, :numeric
      grid.each do |row|
        row.each do |cell|
          cell.value.should == 0
        end
      end
    end

    it "should be initialized to '.' for :alphabet grid" do
      grid = Sudoku::Grid.new 9, :alphabet
      grid.each do |row|
        row.each do |cell|
          cell.value.should == '.'
        end
      end
    end
  end

  describe "#==" do
    it "numeric should be equal to itself" do
      grid = Sudoku::Grid.new 9
      grid.should == grid
    end

    it "alphabet should be equal to itself" do
      grid = Sudoku::Grid.new 9, :alphabet
      grid.should == grid
    end
  end

  describe "#dup" do
    it "should be equal to dup of itself" do
      @grid.should == @grid.dup
    end
  end

  describe "#apply_mask" do
    it "should have all cells empty" do
      mask = Array.new(9){Array.new(9){false}}
      @grid.apply_mask mask
      @grid.empty_cells.should have(81).items
    end

    it "should have all cells set" do
      mask = Array.new(9){Array.new(9){true}}
      @grid.apply_mask mask
      @grid.empty_cells.should be_empty
    end
  end

  describe "#empty_cells" do
    it "new grid should have all cells empty" do
      grid = Sudoku::Grid.new 9
      grid.empty_cells.should have(81).items
    end
  end

  describe "#try" do
    it "in new grid should be possible fit any number in any cell" do
      grid = Sudoku::Grid.new 9
      (1..9).each do |n|
        9.times{|r| 9.times{|c| grid.try(r,c,n).should == true }}
      end
    end

    it "in full grid should not be possible fit any number in any cell" do
      (1..9).each do |n|
        9.times{|r| 9.times{|c| @grid.try(r,c,n).should == false }}
      end
    end
  end

  describe "#possible)" do
    it "new grid should have all numbers possible in all cells" do
      grid = Sudoku::Grid.new 9
      grid.each { |r| r.each {|c| c.possible.should have(9).items }}
    end

    it "full grid should have zero possibilities in all cells" do
      @grid.each {|r| r.each {|c| c.possible.should be_empty}}
    end
  end

end


describe Sudoku::Cell do
end

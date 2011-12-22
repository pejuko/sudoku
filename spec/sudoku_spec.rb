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
      solutions.size.should == 5
    end

    ["easy", "medium", "difficult"].each do |name|
      it "test/#{name}.sud" do
        sud = read_solver name
        solutions = sud.find_solutions
        solutions.size.should == 1
      end
    end

    it "test/impossible.sud" do
      sud = Sudoku::Solver.new Sudoku::Grid.read_file("test/impossible.sud"), 5
      solutions = sud.find_solutions true
      solutions.size.should == 0
    end
  end

end


describe Sudoku::Generator do
  (1..5).each do |level|
    it "level #{level}: should generate new grid with only one possible solution" do
      sud = Sudoku::Generator.new level
      solver = Sudoku::Solver.new sud.grid, 5
      solutions = solver.find_solutions true
      solutions.size.should == 1
    end
  end

  (1..5).each do |level|
    it "level #{level}: should have some empty cells" do
      sud = Sudoku::Generator.new level
      sud.grid.apply_mask sud.mask
      sud.grid.empty_cells.size.should > 0
    end
  end
end


describe Sudoku::Grid do
end


describe Sudoku::Cell do
end

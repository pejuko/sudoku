# Default url mappings are:
#  a controller called Main is mapped on the root of the site: /
#  a controller called Something is mapped on: /something
# If you want to override this, add a line like this inside the class
#  map '/otherurl'
# this will force the controller to be mounted on: /otherurl

class MainController < Controller

  def index
    @level = 4
    @dim = 9
    @chars = :numeric
    @level = request["level"].to_i if request["level"].to_i > 0
    @chars = request["chars"]=="alphabet" ? :alphabet : :numeric

    @title = "Sudoku"

    new_sudoku if (not request["new"].to_s.strip.empty?) or (not session[:sudoku])

    @sudoku = session[:sudoku]
    @hints = session[:hints]
    @solution = session[:solution]

    handle_form
  end

  private

  def new_sudoku
    session[:sudoku] = Sudoku::Generator.new @level, @dim, @chars
    session[:hints] = Array.new(@dim){Array.new(@dim){nil}}
    session[:solution] = Array.new(@dim){Array.new(@dim){nil}}
    request["solution"] = nil
  end

  def handle_form
    get_solution
    check_solution unless request["check"].to_s.strip.empty?
    @show_solution = true unless request["show_solution"].to_s.strip.empty?
    hint unless request["hint"].to_s.strip.empty?
  end

  def check_solution
    correct = true
    @solution.each_with_index do |row, y|
      row.each_with_index do |cell,x|
        correct = false if @sudoku.grid[y][x] != @solution[y][x]
      end
    end

    if request["solution"].is_a?(Hash)
      if correct
        @message = "Correct"
      else
        @error = "False"
      end
    end
  end

  def get_solution
    return if not request["solution"].is_a?(Hash)
    request["solution"].each do |y, row|
      row.each do |x, cell|
        c = @sudoku.grid.chars[0]==1 ? cell.to_i : cell.strip
        @solution[y.to_i][x.to_i] = c unless cell.strip.empty?
      end
    end
    session[:solution] = @solution
  end

  def hint
    possible = []
    @sudoku.mask.each_with_index do |row,y|
      row.each_with_index do |c,x|
        next if @solution[y][x]
        possible << [x,y] unless c
      end
    end
    possible.sort_by!{rand}
    unless possible.empty?
      x,y = possible.first
      @sudoku.mask[y][x] = true
      @hints[y][x] = true
      session[:sudoku] = @sudoku
      session[:hints] = @hints
    else
      @error = "No hint available"
    end
  end

end

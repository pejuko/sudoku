# Default url mappings are:
#  a controller called Main is mapped on the root of the site: /
#  a controller called Something is mapped on: /something
# If you want to override this, add a line like this inside the class
#  map '/otherurl'
# this will force the controller to be mounted on: /otherurl

require 'prawn'

class MainController < Controller

  def index
    @level = session[:level] || 5
    @dim = 9
    @chars = :numeric
    session[:level] = @level = request["level"].to_i if request["level"].to_i > 0
    @chars = request["chars"]=="alphabet" ? :alphabet : :numeric

    @title = "Sudoku"

    new_sudoku if (not request["new"].to_s.strip.empty?) or (not session[:sudoku])

    @sudoku = session[:sudoku]
    @hints = session[:hints]
    @solution = session[:solution]

    handle_form
  end

  def book
    unless request["download"].to_s.empty?
      l = request["level"]
      ref = %~%s/%s/%d/%d/%d/%d/%d/%d~ % [request["format"], request["chars"], (3..8).map{|i|l[i.to_s].to_i}].flatten
      redirect "/pdf/"+ref
    end
  end

  def checkpdf
    pdf = Ramaze::Cache.session.fetch(session[:pdfsid])
    pdfpage = Ramaze::Cache.session.fetch(session[:pdfpage])
    respond( pdf ? "ready" : pdfpage, 200, {'Content-Type' => 'text/plain'} )
  end

  def fetchpdf
    pdf = Ramaze::Cache.session.fetch(session[:pdfsid])
    if pdf
      Ramaze::Cache.session.delete(session[:pdfsid])
      respond pdf, 200, {'Content-Type' => 'application/pdf'}
    end
  end

  def pdf(format, chars, *level)
    pages = level.inject(0){|sum,c| sum += c.to_i}
    pdfsid = session[:pdfsid] = "pdf#{session.sid}"
    pdfpage = session[:pdfpage] = "pdfpage#{session.sid}"
    throw "To many pages" if pages > 30
    Thread.new {
    pdf = Prawn::Document.new(:page_size => format.upcase, :top_margin => 75)
    level.each_with_index do |count, level|
      c = count.to_i
      next if c<=0
      l = level + 1
      c.times do |i|
        Ramaze::Cache.session.store(pdfpage, "#{pdf.page_count}/#{pages}")
        pdf.text "Level #{l}", :align => :center, :size => 32
        w = pdf.bounds.top
        h = pdf.bounds.right
        pos = [
          [[h/2-257, w/2+257], [(h/2)+14, w/2+257]],
          [[h/2-257, (w/2)-14], [(h/2)+14, (w/2)-14]]
        ]
        pos.each do |row|
          row.each do |col|
            pdf.bounding_box( col, :width => 255, :height => 255) do
              pdf.font_size = 16
              pdf.table(new_pdf_sudoku(l, chars.to_sym)) do
                cells.style :width => 27, :height => 27, :align => :center, :font_style => :bold#, :valign => :center
                style row(2), :border_bottom_width => 2
                style row(5), :border_bottom_width => 2
                style column(2), :border_right_width => 2
                style column(5), :border_right_width => 2
              end
            end
          end
        end
        pdf.start_new_page if pdf.page_count < pages
      end
    end
    Ramaze::Cache.session.store(pdfsid, pdf.render)
    }
    respond( "busy", 200, {'Content-Type' => 'text/plain'} )
  end

  def save(*args)
    @sudoku = session[:sudoku]
    @solution = session[:solution]
    get_solution
    get_memory
    ""
  end

  private

  def new_pdf_sudoku(l, chars)
    s = Sudoku::Generator.new(l, 9, chars, 6)
    g = s.grid.dup
    s.mask.each_with_index do |row, y|
      row.each_with_index do |col, x|
        g[y][x].value = "" unless col
      end
    end
    g.each{|row|row.map!{|c|c.value}}
    g
  end

  def new_sudoku
    session[:sudoku] = Sudoku::Generator.new @level, @dim, @chars, 6
    session[:hints] = Array.new(@dim){Array.new(@dim){nil}}
    session[:solution] = Array.new(@dim){Array.new(@dim){nil}}
    request["solution"] = nil
    request["memory"] = nil
    session[:memory] = nil
  end

  def handle_form
    get_solution
    get_memory
    check_solution unless request["check"].to_s.strip.empty?
    @show_solution = true unless request["show_solution"].to_s.strip.empty?
    hint unless request["hint"].to_s.strip.empty?
  end

  def check_solution
    correct = true
    @solution.each_with_index do |row, y|
      row.each_with_index do |cell,x|
        next if cell == nil
        correct = false if @sudoku.grid[y][x].value != @solution[y][x]
      end
    end

    if request["solution"].is_a?(Hash)
      if correct
        @message = "Correct"
      else
        @error = "False"
      end
    end
    correct
  end

  def get_solution
    return if not request["solution"].is_a?(Hash)
    request["solution"].each do |y, row|
      row.each do |x, cell|
        c = @sudoku.grid.chars[0]==1 ? cell.to_i : cell.strip
        @solution[y.to_i][x.to_i] = c unless cell.strip.empty?
      end
    end
    @solution = session[:solution] = @solution
  end

  def get_memory
    session[:memory] = request["memory"] if request["memory"].kind_of?(Hash)
    @memory = session[:memory]
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

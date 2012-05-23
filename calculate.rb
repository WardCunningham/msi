require 'rubygems'
require 'json'
require 'parser2'

class Calculate

  def initialize
    @dot = []
    @node = {}
    @log = File.open "calculate.html", "w"
    @log.puts '<body style="font-family: Arial, Helvetica, sans-serif;"><ol>'

    @parser = Parser.new
    @data = {}
    @tables = {}
    @columns = {}
    @formulas = {}
    Dir.glob 'try6/*.json' do |filename|
      next if filename =~ /Tier3Functions.json$/
      input = load filename
      columns = input['columns']
      data = input['data']
      key = columns[0]
      if filename =~ /\/(\w*)\.json/
        name = $1
        @data[name] = input['data']
        @tables[name] = index key, input
        @columns[name] = input['columns'].reject{|col|col=~/_Formula/}
      end
    end
    load("try6/Tier3Functions.json")['data'].each do |row|
      @formulas[row['Function Name']] = row['Function']
    end
  end

  def node obj, label=nil
    if n = @node[obj]
      return n
    end
    @node[obj] = n = "n#{@node.size}"
    shape = 'shape=square fillcolor=white' if label =~ /fetch/
    @dot << "#{n} [label = \"#{label}\"  #{shape}];"
    n
  end

  def log it, mark, show
    now = it+mark
    @dot << "#{node it}->#{node now, mark.join('\n').gsub(/[ \/]+/,'\n')};"
    @log.puts "<li>#{it.join(" &nbsp; ")}<br><font color=#ccc>#{show.inspect}</font>\n"
    return now
  end

  def close
    @log.close
    File.open("calculate.dot","w") do |file|
      file.puts "strict digraph calculate {"
      file.puts "node [style=filled fillcolor=gold]; edge [dir=back]"
      @dot.each {|line| file.puts line}
      file.puts "}"
    end
  end

  def load filename
    text = File.read(filename)
    input = JSON.parse(text)
  end

  def index key, table
    hash = {}
    table['data'].each do |row|
      hash[row[key]] = row
    end
    return hash
  end

  def fetch it, from, column
    it = log it, ['fetch',column], [from, column]
    (table, key) = from
    throw Exception.new("No table named '#{table}'") unless tab = @tables[table]
    throw Exception.new("No row with key '#{key}' in #{table}") unless row = tab[key]
    throw Exception.new("No column with name '#{column}' in #{table}") unless val = row[column]
    if formula = row["#{column}_Formula"]
      begin
        got = execute it, from, formula
        judge = got == val.to_f ? "<font color=green>GOOD</font>" : "<font color=red>BAD</font>"
        @log.puts "<br>#{judge}: had #{val.inspect}, got #{got.inspect} for #{formula}"
      rescue Exception => e
        log it, ['<font color=red>RESCUE</font>'], "#{e.message}<br>#{e.backtrace.join('<br>')}"
        return val
      end
    else
      @log.puts "<font color=gold>#{val.inspect}</font>"
    end
    val
  end

  def fetchcol it, from, column
    it = log it, ['fetch',column], [from, column]
    (table, key) = from
    val = @data[table].collect do |row|
      # throw Exception.new "Don't fetch columns of formulas yet" if formula = row["#{column}_Formula"]
      row[column.to_s]
    end
    @log.puts "<font color=gold>#{val.inspect}</font>"
    val
  end

  def execute it, from, formula
    it = log it, ['execute'], "<font color=blue>#{formula}</font>"
    expr = @parser.parse_excel formula
    eval it, from, expr
  end

  def num obs
    Integer(obs) rescue Float(obs) rescue obs
  end

  def binary left, right, op
    @log.puts "(#{[*left].length} #{op} #{[*right].length})"
    val = if left.is_a? Array
      if right.is_a? Array
        (1..[left.length, right.length].min).collect {|i| yield num(left[i]), num(right[i])}
      else
        left.collect {|each| yield num(each), num(right)}
      end
    else
      if right.is_a? Array
        right.collect {|each| yield num(left), num(each)}
      else
        yield num(left), num(right)
      end
    end
    @log.puts "<font color=gold>#{val.inspect}</font>"
    val
  end

  def eval it, from, expr
    return nil unless expr
    case
    when s=expr[:sheet]
      throw Exception.new "Can't fetch from sheet: '#{s}'"
    when r=expr[:absrow]||expr[:row]
      c=expr[:abscol]||expr[:col]
      throw Exception.new "Can't fetch row: '#{r}', column: '#{c}'"
    when o=expr[:op]
      it = log it, [o], [expr[:left],expr[:right]].collect {|arg|arg.keys}
      left = eval it, from, expr[:left]
      right = eval it, from, expr[:right]
      case o
      when '+': binary(left,right,o) {|left,right| left + right}
      when '-': binary(left,right,o) {|left,right| left - right}
      when '*': binary(left,right,o) {|left,right| left * right}
      when '/': binary(left,right,o) {|left,right| left / right}
      when '=': binary(left,right,o) {|left,right| left == right ? 1 : 0}
      when '<>': binary(left,right,o) {|left,right| left != right ? 1 : 0}
      when '>': binary(left,right,o) {|left,right| left > right ? 1 : 0}
      when '<': binary(left,right,o) {|left,right| left < right ? 1 : 0}
      when '>=': binary(left,right,o) {|left,right| left >= right ? 1 : 0}
      when '<=': binary(left,right,o) {|left,right| left <= right ? 1 : 0}
      else throw Exception.new "Don't know op: '#{o}'"
      end
    when f=expr[:function]
      # "SUM", "RANK", "LOWER", "LOG", "MAX", "IFERROR", "MIN", "AVERAGE", "IF", "VLOOKUP"
      args = [expr[:args]].flatten
      it = log it, [f], args.collect {|arg|arg.keys}
      case f
      when 'SUM': sum args.collect{|arg| eval(it,from,arg)}
      when 'MIN': min args.collect{|arg| eval(it,from,arg)}
      when 'AVERAGE': avg args.collect{|arg| eval(it,from,arg)}
      when 'VLOOKUP': vlookup it, eval(it,from,args[0]), args[1], args[2], eval(it,from,args[3])
      when 'IF': eval(it,from,args[0]) ? eval(it,from,args[1]) : eval(it,from,args[2])
      else throw Exception.new "Don't know function: '#{f}'"
      end
    when c=expr[:column]
      tab = (expr[:table]||from[0]).to_s
      cols = @columns[tab]
      if ending=expr[:ending]
        if expr[:current]
          indx = cols.index(c.to_s) .. cols.index(ending[:column].to_s)
          it = log it, ["#{expr[:current]}[]:[]"], cols[indx]
          range = cols[indx].collect{ |col| fetch it,[tab, from[1]], col }
        else
          throw Exception "Don't yet handle 2D range"
        end
      else
        it = log it, ["#{expr[:current]}[]"], c
        if expr[:current]
          fetch it, [tab, from[1]], c.to_s
        else
          fetchcol it, [tab, nil], c.to_s
        end
      end
    when f=expr[:formula]
      throw Exception.new "Don't know formula: '#{f}'" unless fmla = @formulas[f.to_s]
      it = log it, ['formula',f], fmla
      execute it, from, fmla
    when s=expr[:string]:
      return s.to_s
    when n=expr[:number]
      return n.to_f
    when b=expr[:boolean]
      return b.to_s[0]==?T ? 1 : 0
    else
      log it, ["<font color=red>Eval</font>"],expr
    end
  end

  def sum vector
    @log.puts "<br>sum: #{vector.inspect}"
    vector.flatten.inject(0){|sum,each| sum + each.to_f}
  end

  def min vector
    @log.puts "<br>min: #{vector.inspect}"
    vector.flatten.inject(0){|sum,each| sum < each.to_f ? sum : each.to_f}
  end

  def avg vector
    @log.puts "<br>avg: #{vector.inspect}"
    vector.flatten.inject(0){|sum,each| sum + each.to_f} / vector.flatten.length
  end

  def vlookup it, key, table, column, exact
    t=table[:formula]
    throw Exception.new "Can't find table '#{t}'" unless tab = @tables[t.to_s]
    throw Exception.new "Can't find row for '#{key}' in table #{t}" unless row = tab[key.to_s]
    c = column[:formula]
    f = @formulas[c.to_s]
    r = @parser.parse_excel f
    n = (r[:abscol].to_s[0].to_i)-('A'[0].to_i)+1
    col = @columns[t.to_s][n]
    throw Exception.new "Can't find column '#{col}' in table #{t}" unless val = row[col]
    fetch it, [t.to_s, key.to_s], col
  end

end

@calc = Calculate.new

def test expr
  puts expr
  puts @calc.execute [], "=#{expr}"
end

# test "(1/3)*3"
# test 'SUM(10,"20",30)'
# test 'IF(5>10,"good",20.665+1)'

begin
  # puts @calc.fetch [],['Tier3ChemistryData','Cotton fabric'], 'Substance'
  # puts @calc.fetch [],['Tier3ChemistryData','Cotton fabric'], 'Carcinogen'
  puts @calc.fetch [],['Tier1MSISummary','Cotton fabric'], ' Chemistry Total'
ensure
  @calc.close
end
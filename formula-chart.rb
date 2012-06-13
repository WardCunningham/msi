require 'rubygems'
require 'parser2'
require 'json'

def load filename
  text = File.read(filename)
  input = JSON.parse(text)
  columns = input['columns']
  data = input['data']
  puts "#{filename}: #{data.length} rows x #{columns.length} columns"
  # puts columns.inspect
  # puts data[0].inspect
  return input
end

@functs = {}
@sheets = {}
@tables = {}
@columns = {}
@strings = {}
@numbers = {}
@undef = {}
@ref = {}

@formulas = {}
@tablesWithFormulas = {}
@parser = Parser.new

@trouble = 0
def trouble message
  puts "\nTrouble #{@trouble += 1}"
  puts message
end

def leftpos expr
  n = 9999
  case
  when expr.kind_of?(Hash) then expr.each {|k,v| n = [n, leftpos(v)].min}
  when expr.kind_of?(Array) then expr.each {|v| n = [n, leftpos(v)].min}
  when expr.kind_of?(Parslet::Slice) then n = [n, expr.offset].min
  else puts "don't know leftpos of #{expr.class}"
  end
  return n
end

def rightpos expr
  n = -1
  case
  when expr.kind_of?(Hash) then expr.each {|k,v| n = [n, rightpos(v)].max}
  when expr.kind_of?(Array) then expr.each {|v| n = [n, rightpos(v)].max}
  when expr.kind_of?(Parslet::Slice) then n = [n, expr.offset+expr.to_s.length].max
  else puts "don't know rightpos of #{expr.class}"
  end
  return n
end

def quote string
  trouble "quoting empty" if string.to_s.length < 1
  "\"#{string.to_s.gsub(/"/,'\"').gsub(/([a-z0-9]|HG|SW|SI)[_ \/]*([A-Z(])/,'\1\n\2')}\""
end

def dot_table from, table
  if @tablesWithFormulas[table.to_s] == 1
    @dot << "#{quote table} [shape=folder fillcolor=white URL=\"#{table}.svg\"]"
    @dot_index << "#{quote table} [shape=folder fillcolor=white URL=\"#{table}.svg\"]"
  else
    @dot << "#{quote table} [shape=folder fillcolor=white fontcolor=gray]"
    @dot_index << "#{quote table} [shape=folder fillcolor=white fontcolor=gray]"
  end
  @dot << "#{quote from} -> #{quote table};"
  @dot_index << "#{quote @dot_index_table} -> #{quote table};"
end

@checked_url = {}
def column_url table, column
  short = column.to_s.gsub /[^A-Za-z0-9]/,''
  file = "#{table}-#{short}.html"
  check = "#{@dot_index_table} #{file}"
  trouble "Table #{@dot_index_table} references missing column '#{column}' in '#{table}'" unless File.exists? "#{@try}/Processed/#{file}" or @checked_url[check]
  @checked_url[check] = 1
  return "\"#{file}\""
end

def eval str, from, expr
  return unless expr
  # puts "--#{expr.inspect}"
  case
  when s=expr[:sheet]
    label = expr[:absrow] && expr[:abscol] ? "[label=\"$\"]" : ""
    # label = "[label=\"#{[:abscol, :absrow].collect {|abs| expr[abs] ? "$" : "."}}\"]"
    @dot << "#{quote s} [fillcolor=white]"
    @dot << "#{quote from} -> #{quote s} #{label}"
    @sheets[s.to_s] = 1
  when r=expr[:abscol]||expr[:col]
    @dot << "#{quote from} -> #{quote r}"
  when o=expr[:op]
    eval str, from, expr[:left]
    eval str, from, expr[:right]
  when o=expr[:opsp]
    eval str, from, expr[:left]
    eval str, from, expr[:right]
  when f=expr[:function]
    tip = "\"#{str[leftpos(expr)..rightpos(expr)].gsub /"/, '\"'}\""
    succ = "#{from}-#{f}"
    @dot << "#{quote succ} [shape=none fillcolor=lightgray label=#{quote f} tooltip=#{tip}]"
    @dot << "#{quote from} -> #{quote succ};"
    @functs[f.to_s] = 1
    if f == 'VLOOKUP'
      (key, tab, col, bol) = expr[:args]
      dot_table succ, tab[:formula]
      [key, col, bol].each  {|arg| eval str, succ, arg}
    else
      [expr[:args]].flatten.each {|arg| eval str, succ, arg}
    end
  when c=expr[:column]
    label = expr[:current] ? "[label=\"@\"]" : ""
    if t=expr[:table]
      @dot << "#{col = quote t+c} [fillcolor=white, label=#{quote c} URL=#{column_url t, c}]"
      dot_table t+c, t
    else
      @dot << "#{col = quote c} [fillcolor=gold URL=#{column_url @dot_index_table, c}]"
    end
    @dot << "#{quote from} -> #{col} #{label};"
    @columns[c.to_s] = 1
    @tables[expr[:table].to_s]=1 if expr[:table]
  when f=expr[:formula]
    # @formulas[f.to_s] = 1
    defn = @formulas[f.to_s]
    if defn
      @ref[f.to_s] = 1
      @dot << "#{quote 'f-'+f} [shape=box fillcolor=lightblue label=#{quote f}tooltip=\"#{defn.gsub /"/, '\"'}\"]"
      parse defn, 'f-'+f
    else
      @undef[f.to_s] = 1
    end
    @dot << "#{quote from} -> #{quote 'f-'+f};"
  when s=expr[:string]
    @strings[s.to_s] = 1
  when n=expr[:number]
    @numbers[n.to_s] = 1
  when b=expr[:boolean]
    @numbers[b.to_s] = 1
  else
    puts "Can't Eval:"
    puts JSON.pretty_generate(expr)
  end
end

@checked_parses = {}
def parse str, binding='root'
  # puts "---------------------\n#{binding} #{str}"
  expr = @parser.parse_excel str
  # puts JSON.pretty_generate(expr)
  eval str, binding, expr
rescue Parslet::ParseFailed => err
  msg = "#{@dot_index_table}: #{binding} #{str}"
  unless @checked_parses[msg]
    trouble msg
    @checked_parses[msg] = 1
    puts err
    puts @parser.error_tree
  end
end


# parse "=(10*(1-(-1.75179473531518E-15*Tier1Raw!G10^6 + 1.4557896802775E-12*Tier1Raw!G10^5 - 8.4072904671037E-11*Tier1Raw!G10^4 - 2.13762500849562E-07*Tier1Raw!G10^3 + 0.0000580307924400447*Tier1Raw!G10^2 - 0.000467308212137141*Tier1Raw!G10)))"

# parse "=IF(Tier1Raw!H11<0,15,IF(Tier1Raw!H11>17,(15*(1-(-0.0000323419744468201*Tier1Raw!H11^2 + 0.00646102566117069*Tier1Raw!H11 + 0.673902585769844))),(15*(1-(-0.00143091294220916*Tier1Raw!H11^2 + 0.0705541152858646*Tier1Raw!H11)))))"

# parse "=IFERROR(SUM(IF(([@TransportSenario]=Tier3TransportSenario[Scenario]),INDIRECT(\"Tier3TransportSenario[\"&[@ProcessType]&\"]\"))),0)"

# @dot = []
# parse "=IFERROR(VLOOKUP([@[Textile Location]],Tier3HydroSources,COLUMN(Tier3HydroSources[[#Headers],[% Renewable (no big hydro)]]),FALSE),\"\")"
# @dot.each {|e| puts e}
# exit

# load("try8/Tier3Functions.json")['data'].each do |row|
#   parse row['Function'],row['Function Name']
# end

@try = 'db/6-11-12'
load("#{@try}/Raw/Tier3Functions.json")['data'].each do |row|
  @formulas[row['Function Name']] = row['Function']
end

File.open("#{@try}/Processed/formulas.txt") do |file|
  while (line = file.gets)
    (filename, column, formula) = line.chomp.split("\t")
    (p1, p2, p3, table, sufix) = filename.split(/[\.\/]/)
    @tablesWithFormulas[table] = 1
  end
end

@dot_index = []
Dir.glob("#{@try}/Raw/*.json") do |focus|
  (p1, p2, p3, table, sufix) = focus.split(/[\.\/]/)
  @dot_index_table = table
  trouble "can't grok table name" unless table.length>0
  puts "\n**** #{table} ****"
  @dot = []
  File.open("#{@try}/Processed/formulas.txt") do |file|
    while (line = file.gets)
      (filename, column_formula, formula) = line.chomp.split("\t")
      next unless filename == focus
      (column, sufix) = column_formula.split('_')
      (db, date, raw, table, sufix) = filename.split /[\/\.]/
      @dot << "#{table} [shape=folder fillcolor=white label=#{quote table}]"
      @dot << "#{quote column} [fillcolor=white URL=#{column_url table, column}]"
      @dot << "#{quote(column_formula+formula)} [shape=box fillcolor=gold label=#{quote column_formula} tooltip=\"#{formula.gsub /"/, '\"'}\"]"
      @dot << "#{table} -> #{quote column} -> #{quote(column_formula+formula)}"
    end
  end
  File.open("#{@try}/Processed/formulas.txt") do |file|
    while (line = file.gets)
      (filename, column_formula, formula) = line.chomp.split("\t")
      (column, sufix) = column_formula.split('_')
      next unless filename == focus
      parse formula, column_formula+formula
    end
  end
  next unless @dot.length > 0
  File.open("formula-chart.dot", 'w') do |f|
    f.puts "strict digraph \"\" {\nnode[style=filled, fillcolor=pink];\n#{@dot.join("\n")}\n}"
  end
  puts `cat formula-chart.dot | dot -Tsvg -o#{@try}/Processed/#{table}.svg`
end

File.open("formula-chart.dot", 'w') do |f|
  f.puts "strict digraph \"\" {\nnode[style=filled, fillcolor=pink];\n#{@dot_index.join("\n")}\n}"
end
puts `cat formula-chart.dot | dot -Tsvg -o#{@try}/Processed/index.svg`


puts "\nsheets: #{@sheets.keys.inspect}"
puts "\nfuncts: #{@functs.keys.inspect}"
puts "\ntables: #{@tables.keys.inspect}"
puts "\ncolumns: #{@columns.keys.inspect}"
puts "\nstrings: #{@strings.keys.inspect}"
puts "\nnumbers: #{@numbers.keys.inspect}"
puts "\nundef: #{@undef.keys.inspect}"
puts "\nunref: #{(@formulas.keys - @ref.keys).inspect}"

puts "\n\n#{@trouble} trouble"
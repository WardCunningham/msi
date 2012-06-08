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



def quote string
  trouble "quoting empty" if string.to_s.length < 1
  "\"#{string.to_s.gsub(/([a-z0-9]|GHG|MSW)[_ \/]*([A-Z(])/,'\1\n\2')}\""
end

def dot_table from, table
  if @tablesWithFormulas[table.to_s] == 1
    @dot << "#{quote table} [shape=folder fillcolor=white URL=\"#{table}.svg\"]"
  else
    @dot << "#{quote table} [shape=folder fillcolor=white fontcolor=gray]"
  end
  @dot << "#{quote from} -> #{quote table};"
end

def eval from, expr
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
    eval from, expr[:left]
    eval from, expr[:right]
  when o=expr[:opsp]
    eval from, expr[:left]
    eval from, expr[:right]
  when f=expr[:function]
    succ = "#{from}-#{f}"
    @dot << "#{quote succ} [shape=none fillcolor=lightgray label=#{quote f}]"
    @dot << "#{quote from} -> #{quote succ};"
    @functs[f.to_s] = 1
    if f == 'VLOOKUP'
      (key, tab, col, bol) = expr[:args]
      dot_table succ, tab[:formula]
      [key, col, bol].each  {|arg| eval succ, arg}
    else
      [expr[:args]].flatten.each {|arg| eval succ, arg}
    end
  when c=expr[:column]
    label = expr[:current] ? "[label=\"@\"]" : ""
    if t=expr[:table]
      @dot << "#{col = quote t+c} [fillcolor=white, label=#{quote c}]"
      dot_table t+c, t
    else
      @dot << "#{col = quote c} [fillcolor=gold]"
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

def parse str, binding='root'
  puts "---------------------\n#{binding}#{str}"
  expr = @parser.parse_excel str
  # puts JSON.pretty_generate(expr)
  eval binding, expr
rescue Parslet::ParseFailed => err
  trouble err
  puts @parser.error_tree
end


# parse "=(10*(1-(-1.75179473531518E-15*Tier1Raw!G10^6 + 1.4557896802775E-12*Tier1Raw!G10^5 - 8.4072904671037E-11*Tier1Raw!G10^4 - 2.13762500849562E-07*Tier1Raw!G10^3 + 0.0000580307924400447*Tier1Raw!G10^2 - 0.000467308212137141*Tier1Raw!G10)))"

# parse "=IF(Tier1Raw!H11<0,15,IF(Tier1Raw!H11>17,(15*(1-(-0.0000323419744468201*Tier1Raw!H11^2 + 0.00646102566117069*Tier1Raw!H11 + 0.673902585769844))),(15*(1-(-0.00143091294220916*Tier1Raw!H11^2 + 0.0705541152858646*Tier1Raw!H11)))))"

# parse "=IFERROR(SUM(IF(([@TransportSenario]=Tier3TransportSenario[Scenario]),INDIRECT(\"Tier3TransportSenario[\"&[@ProcessType]&\"]\"))),0)"

# @dot = []
# parse "=IF(LOWER(Tier3WaterData[@Fabric])=\"y\",Tier3WaterData[@[Fabric Add on]],1)"
# @dot.each {|e| puts e}
# exit

# load("try8/Tier3Functions.json")['data'].each do |row|
#   parse row['Function'],row['Function Name']
# end

@try = 'try9'
load("#{@try}/Tier3Functions.json")['data'].each do |row|
  @formulas[row['Function Name']] = row['Function']
end

File.open('formulas.txt') do |file|
  while (line = file.gets)
    (filename, column, formula) = line.chomp.split("\t")
    (prefix, table, sufix) = filename.split(/[\.\/]/)
    @tablesWithFormulas[table] = 1
  end
end
puts @tablesWithFormulas.inspect

Dir.glob("#{@try}/*.json") do |focus|
  (prefix, table, sufix) = focus.split(/[\.\/]/)
  trouble "can't grok table name" unless table.length>0
  puts "\n**** #{table} ****"
  @dot = []
  File.open('formulas.txt') do |file|
    while (line = file.gets)
      (filename, column_formula, formula) = line.chomp.split("\t")
      (column, sufix) = column_formula.split('_')
      next unless filename == focus
      @dot << "#{table} [shape=folder fillcolor=white label=#{quote table}]"
      @dot << "#{quote column} [fillcolor=white]"
      @dot << "#{quote column_formula} [shape=box fillcolor=gold tooltip=\"#{formula.gsub /"/, '\"'}\"]"
      @dot << "#{table} -> #{quote column} -> #{quote column_formula}"
    end
  end
  File.open('formulas.txt') do |file|
    while (line = file.gets)
      (filename, column_formula, formula) = line.chomp.split("\t")
      (column, sufix) = column_formula.split('_')
      next unless filename == focus
      parse formula, column_formula
    end
  end
  next unless @dot.length > 0
  File.open("formula-chart.dot", 'w') do |f|
    f.puts "strict digraph \"\" {\nnode[style=filled, fillcolor=pink];\n#{@dot.join("\n")}\n}"
  end
  puts `cat formula-chart.dot | dot -Tsvg -o#{@try}/svg/#{table}.svg`
end

puts "\nsheets: #{@sheets.keys.inspect}"
puts "\nfuncts: #{@functs.keys.inspect}"
puts "\ntables: #{@tables.keys.inspect}"
puts "\ncolumns: #{@columns.keys.inspect}"
puts "\nstrings: #{@strings.keys.inspect}"
puts "\nnumbers: #{@numbers.keys.inspect}"
puts "\nundef: #{@undef.keys.inspect}"
puts "\nunref: #{(@formulas.keys - @ref.keys).inspect}"

puts "\n\n#{@trouble} trouble"
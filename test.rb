require 'rubygems'
require 'parslet'
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

class Fun < Parslet::Parser
  rule(:sp) { match('\s').repeat(1) }
  rule(:sp?) { sp.maybe }
  rule(:eq) { match('=') >> sp? }
  rule(:addop) { match['+-'] >> sp? }
  rule(:multop) { match['*/'] >> sp? }
  rule(:logicop) { (match('<') >> match('>') | match['<>'] >> match('=') | match['=<>']) >> sp? }
  rule(:lsqr) { match('\[') >> sp? }
  rule(:rsqr) { match('\]') >> sp? }
  rule(:lparn) { match('\(') >> sp? }
  rule(:rparn) { match('\)') >> sp? }
  rule(:at) { match('@') >> sp? }
  rule(:comma) { match(',') >> sp? }
  rule(:dot) { match('\.') }
  rule(:digits) { match['0-9'].repeat(1) }
  rule(:letters) { match['A-Z'].repeat(1) }
  rule(:dollar) { match('\$') >> sp? }
  rule(:bang) { match('\!') >> sp? }
  rule(:coln) { match('\:') >> sp? }
  rule(:name) { match['a-zA-Z'] >> match['a-zA-Z0-9'].repeat(1) }
  rule(:file) { match("'") >> match["^'"].repeat(0).as(:file) >> match("'") }
  
  rule(:num) { ((digits >> (dot >> digits.maybe).maybe) | (dot >> digits)).as(:number)}
  rule(:frml) { name.as(:formula)}
  rule(:r) { dollar >> digits.as(:absrow) | digits.as(:row) }
  rule(:c) { dollar >> letters.as(:abscol) | letters.as(:col) }
  rule(:sheet) { name.as(:sheet) }
  rule(:cell) { (sheet >> bang).maybe >> c >> r }
  rule(:args) { expr >> (comma >> expr).repeat(0) }
  rule(:call) { name.as(:function) >> lparn >> args.as(:args) >> rparn }
  rule(:cname) { match['^\]'].repeat(1).as(:column) }
  rule(:ending) { coln >> lsqr >> cname.as(:ending) >> rsqr }
  rule(:col) { (lsqr >> cname >> rsqr >> ending.maybe) | cname }
  rule(:ref) { (name | file).as(:table).maybe >> lsqr >> at.as(:current).maybe >> col >> rsqr}
  rule(:str) { match('"') >> match['^"'].repeat(0).as(:string) >> match('"') }
  rule(:paren) { (lparn >> expr >> rparn) }
  rule(:unit) { paren | str | ref | call | cell | frml | num }
  
  rule(:prod) { unit.as(:left) >> ( multop.as(:op) >> expr.as(:right) ).maybe }
  rule(:sum) { prod.as(:left) >> ( addop.as(:op) >> expr.as(:right) ).maybe }
  rule(:logic) { sum.as(:left) >> ( logicop.as(:op) >> expr.as(:right) ).maybe }

  rule(:expr) { logic }
  rule(:defn) { eq >> expr }
  root(:defn)
end

class Fix < Parslet::Transform
  rule(:left => subtree(:tree)) {tree}
  rule(:name => simple(:name)) { {:name => name.to_s} }
end

@functs = {}
@sheets = {}
@tables = {}
@columns = {}
@formulas = {}
@strings = {}
@numbers = {}

@dot = []
def quote string
  "\"#{string.to_s.gsub(/([a-z0-9]|GHG|MSW)[_ \/]*([A-Z])/,'\1\n\2')}\""
end

def eval from, expr
  return unless expr
  puts "--#{expr.inspect}"
  case
  when s=expr[:sheet]
    label = expr[:absrow] && expr[:abscol] ? "[label=\"$\"]" : ""
    # label = "[label=\"#{[:abscol, :absrow].collect {|abs| expr[abs] ? "$" : "."}}\"]"
    @dot << "#{quote s} [fillcolor=white];" unless @columns[@sheets[s.to_s]]
    @dot << "#{quote from} -> #{quote s} #{label};"
    @sheets[s.to_s] = 1
  when r=expr[:absrow]||expr[:row]
    # nothing special yet
  when o=expr[:op]
    eval from, expr[:left]
    eval from, expr[:right]
  when f=expr[:function]
    # @dot << "#{quote from} -> #{quote f};"
    @functs[f.to_s] = 1
    [expr[:args]].flatten.each {|arg| eval from, arg}
  when c=expr[:column]
    label = expr[:current] ? "[label=\"@\"]" : ""
    @dot << "#{quote c} [fillcolor=lightgray];" unless @columns[c.to_s]
    @dot << "#{quote from} -> #{quote c} #{label};"
    @dot << "#{quote c} -> #{quote expr[:table]};" if expr[:table]
    @columns[c.to_s] = 1
    @tables[expr[:table].to_s]=1 if expr[:table]
  when f=expr[:formula]
    @dot << "#{quote from} -> #{quote f};"
    @formulas[f.to_s] = 1
  when s=expr[:string]
    @strings[s.to_s] = 1
  when n=expr[:number]
    @numbers[n.to_s] = 1
  else
    puts "Can't Eval:"
    puts JSON.pretty_generate(expr)
  end
end

@trouble = 0
def parse str, binding=''
  fun = Fun.new
  puts "---------------------\n#{binding}#{str}"
  expr = Fix.new.apply(fun.parse(str))
  # puts JSON.pretty_generate(expr)
  eval binding, expr
rescue Parslet::ParseFailed => err
  @trouble += 1
  puts "trouble #{@trouble}: ", err, fun.root.error_tree
end

# parse "=VLOOKUP(C10,'C:UsersJamieDropboxContractingNikeNike MAT Linked FilesRevampedSource2-15-12[Tier 3 internal.xls]Assigned Weights and Tables'!$A$253:$B$289,2)"
# exit

# load("try6/Tier3Functions.json")['data'].each do |row|
#   parse row['Function'],row['Function Name']
# end

File.open('formulas.txt') do |file|
  n = 0
  while (line = file.gets)
    n += 1
    parse line.chomp, "formulas(#{n})" unless line =~ /'C:/
  end
end

puts "\nsheets: #{@sheets.keys.inspect}"
puts "\nfuncts: #{@functs.keys.inspect}"
puts "\ntables: #{@tables.keys.inspect}"
puts "\ncolumns: #{@columns.keys.inspect}"
puts "\nformulas: #{@formulas.keys.inspect}"
puts "\nstrings: #{@strings.keys.inspect}"
puts "\nnumbers: #{@numbers.keys.inspect}"

# File.open('test.dot', 'w') do |f|
#   f.puts "\ndigraph nmsi {\ngraph[aspect=5];\nnode[style=filled, fillcolor=gold];\n#{@dot.join("\n")}\n}"
# end

puts "\n\n#{@trouble} trouble"
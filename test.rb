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
  rule(:eq) { match('=') }
  rule(:addop) { match['+-'] }
  rule(:multop) { match['*/'] }
  rule(:logicop) { match['='] }
  rule(:lsqr) { match('\[') }
  rule(:rsqr) { match('\]') }
  rule(:lparn) { match('\(') }
  rule(:rparn) { match('\)') }
  rule(:at) { match('@') }
  rule(:comma) { match(',') }
  rule(:dot) { match('\.') }
  rule(:digits) { match['0-9'].repeat(1) }
  rule(:letters) { match['a-zA-Z'].repeat(1) }
  rule(:dollar) { match('$') }
  rule(:bang) { match('\!') }
  rule(:name) { match['a-zA-Z'] >> match['a-zA-Z0-9'].repeat(1) }
  
  rule(:num) { ((digits >> (dot >> digits.maybe).maybe) | (dot >> digits)).as(:number)}
  rule(:frml) { name.as(:formula)}
  rule(:r) { dollar >> digits.as(:absrow) | digits.as(:row) }
  rule(:c) { dollar >> letters.as(:abscol) | letters.as(:col) }
  rule(:sheet) { name.as(:sheet) }
  rule(:cell) { (sheet >> bang).maybe >> c >> r }
  rule(:args) { expr >> (comma >> expr).repeat(0) }
  rule(:call) { name.as(:function) >> lparn >> args.as(:args) >> rparn }
  rule(:cname) { match['^\]'].repeat(1).as(:column) }
  rule(:col) { (lsqr >> cname >> rsqr) | cname }
  rule(:ref) { name.as(:table) >> lsqr >> at.as(:current).maybe >> col >> rsqr }
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
  "\"#{string.to_s.gsub(/([a-z0-9])[_ \/]?([A-Z])/,'\1\n\2')}\""
end

def eval from, expr
  return unless expr
  puts "--#{expr.inspect}"
  case
  when s=expr[:sheet]
    # @dot << "#{quote from} -> #{quote s};"
    @sheets[s.to_s] = 1
  when o=expr[:op]
    eval from, expr[:left]
    eval from, expr[:right]
  when f=expr[:function]
    # @dot << "#{quote from} -> #{quote f};"
    @functs[f.to_s] = 1
    [expr[:args]].flatten.each {|arg| eval from, arg}
  when t=expr[:table]
    @dot << "#{quote from} -> #{quote expr[:column]};"
    @dot << "#{quote expr[:column]} -> #{quote t};"
    @columns[expr[:column].to_s] = 1
    @tables[t.to_s]=1
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
  puts err, fun.root.error_tree
  @trouble += 1
end

load("try4UTF8/Tier3Functions.json")['data'].each do |row|
  parse row['Function'],row['Function Name']
end

puts "\nsheets: #{@sheets.keys.inspect}"
puts "\nfuncts: #{@functs.keys.inspect}"
puts "\ntables: #{@tables.keys.inspect}"
puts "\ncolumns: #{@columns.keys.inspect}"
puts "\nformulas: #{@formulas.keys.inspect}"
puts "\nstrings: #{@strings.keys.inspect}"
puts "\nnumbers: #{@numbers.keys.inspect}"

File.open('test.dot', 'w') do |f|
  f.puts "\ndigraph nmsi {\nnode[style=filled, fillcolor=gold]\n#{@dot.join("\n")}\n}"
end

puts "\n\n#{@trouble} trouble"
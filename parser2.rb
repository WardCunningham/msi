require 'rubygems'
require 'parslet'

class Parser
  class Fun < Parslet::Parser
    rule(:sp) { match('\s').repeat(1) }
    rule(:sp?) { sp.maybe }
    rule(:eq) { match('=') >> sp? }
    rule(:addop) { match['+-'] >> sp? }
    rule(:multop) { match['*/'] >> sp? }
    rule(:relop) { (match('<') >> match('>') | match['<>'] >> match('=') | match['=<>']) >> sp? }
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

    rule(:bool) { (str('TRUE') | str('FALSE')).as(:boolean)}
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
    rule(:quot) { match('"') >> match['^"'].repeat(0).as(:string) >> match('"') }
    rule(:paren) { (lparn >> expr >> rparn) }
    rule(:unit) { paren | quot | bool | ref | call | cell | frml | num }

    rule(:prod) { unit.as(:left) >> ( multop.as(:op) >> expr.as(:right) ).maybe }
    rule(:sum) { prod.as(:left) >> ( addop.as(:op) >> expr.as(:right) ).maybe }
    rule(:rel) { sum.as(:left) >> ( relop.as(:op) >> expr.as(:right) ).maybe }

    rule(:expr) { rel }
    rule(:defn) { eq >> expr }
    root(:defn)
  end

  class Fix < Parslet::Transform
    rule(:left => subtree(:tree)) {tree}
    rule(:name => simple(:name)) { {:name => name.to_s} }
  end

  def initialize
    @fun = Fun.new
    @fix = Fix.new
  end

  def parse_excel formula
    @fix.apply @fun.parse formula
  end

  def error_tree
    @fun.root.error_tree
  end
end
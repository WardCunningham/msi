require 'rubygems'
require 'parslet'
require 'json'

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
  
  rule(:num) { ((digits >> (dot >> digits.maybe).maybe) | (dot >> digits)).as(:number)}
  rule(:name) { (match['a-zA-Z'] >> match['a-zA-Z0-9'].repeat(1)).as(:name) }
  rule(:r) { dollar >> digits.as(:absrow) | digits.as(:row) }
  rule(:c) { dollar >> letters.as(:abscol) | letters.as(:col) }
  rule(:cell) { name >> bang >> c >> r }
  rule(:args) { expr >> (comma >> expr).repeat(0) }
  rule(:call) { name.as(:function) >> lparn >> args.as(:args) >> rparn }
  rule(:cname) { match['^\]'].repeat(1).as(:column) }
  rule(:col) { (lsqr >> cname >> rsqr) | cname }
  rule(:ref) { name.as(:table) >> lsqr >> at.as(:current).maybe >> col >> rsqr }
  rule(:str) { match('"') >> match['^"'].repeat(0).as(:string) >> match('"') }
  rule(:paren) { (lparn >> expr >> rparn) }
  rule(:unit) { paren | str | ref | call | cell | name | num }
  
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

@trouble = 0
def parse str
  fun = Fun.new
  puts "----------------------------------------\n#{str}\n----------------------------------------"
  # puts JSON.pretty_generate(fun.parse(str))
  puts JSON.pretty_generate(Fix.new.apply(fun.parse(str)))
  # puts Fix.new.apply(fun.parse(str)).inspect
rescue Parslet::ParseFailed => err
  puts err, fun.root.error_tree
  @trouble += 1
end

# parse "=WaterFinishing+WaterProcessTotal*WaterFabricFactor"
# parse "=Tier3WaterData[@Fabric]"
# parse "=Tier3ProcessInformation[Material]"
# parse "=Tier3WaterData[@[Scouring/Washing]]"
# parse "=Tier3WaterData[@[Scouring/Washing]]+WaterProcessTotal*WaterFabricFactor"
# parse "=(Tier3WaterData[@[Scouring/Washing]]+WaterProcessTotal)*WaterFabricFactor"
# parse "=Tier3ProcessInformation[Material]=Tier3WaterData[@Material]"
# parse "=(\"Water\"=Tier3ProcessInformation[ProcessType])"
parse "=Weighting!$H$2"
# parse "=SUM(Tier3ProcessInformation[Material/Washing],Tier3ProcessInformation[Material])"
# parse "=SUM((Tier3ProcessInformation[Material]=Tier3WaterData[@Material])*(\"Water\"=Tier3ProcessInformation[ProcessType])*(Tier3ProcessInformation[Type per Phase]))"
# parse "=(Tier3ProcessInformation[Material]=Tier3WaterData[@Material])*(\"Water\"=Tier3ProcessInformation[ProcessType])*(Tier3ProcessInformation[Type per Phase])"
# 
# parse "=Tier3WaterData[@[Greige/Other]]+Tier3WaterData[@Desizing]+Tier3WaterData[@[Scouring/Washing]]+Tier3WaterData[@Bleaching]+Tier3WaterData[@Fulling]+Tier3WaterData[@Mercerization]+Tier3WaterData[@Dyeing]+Tier3WaterData[@Printing]+Tier3WaterData[@[Rinsing/Finishing]]"
# parse "=SUM((Tier3ProcessInformation[Material]=Tier3WaterData[@Material])*(\"Water\"=Tier3ProcessInformation[ProcessType])*(Tier3ProcessInformation[Type per Phase]))"
# parse "=IF(LOWER(Tier3WaterData[@Fabric])=\"y\",Tier3WaterData[@[Fabric Add on]],1)"
# parse "=IF(LOWER(Tier3WaterData[@Fabric])=\"y\",Tier3WaterData[@[Fabric Add on]],1)"

puts "\n\n#{@trouble} trouble"
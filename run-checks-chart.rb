# run the static checks, and the static chart
# for most recent json files

try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
puts "Run for version #{try}."

puts `ruby checks.rb > #{try}/Processed/trouble-checks.txt`
puts `tail #{try}/Processed/trouble-checks.txt`

puts `ruby formula-chart.rb > #{try}/Processed/trouble-chart.txt`
puts `tail #{try}/Processed/trouble-chart.txt`
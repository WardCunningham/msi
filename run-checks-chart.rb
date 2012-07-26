# run the static checks, and the static chart
# for most recent json files

try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
puts "Run for version #{try}."

puts `ruby checks.rb > #{try}/Processed/trouble-checks.txt`
puts "trouble-checks.txt: " + `tail -1 #{try}/Processed/trouble-checks.txt`

puts `ruby formula-chart.rb > #{try}/Processed/trouble-chart.txt`
puts "trouble-chart.txt: " + `tail -1 #{try}/Processed/trouble-chart.txt`

puts `ruby folded-pages.rb > #{try}/Processed/trouble-pages.txt`
puts "trouble-pages.txt: " + `tail -1 #{try}/Processed/trouble-pages.txt`

puts `cp -R #{try}/Processed/ ~/Smallest-Federated-Wiki/client/chart`

puts "done"
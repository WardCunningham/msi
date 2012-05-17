require 'rubygems'
require 'json'
errors = 0
line = 1

File.open('try3UTF8/Tier3SubstanceData.json','r') do |file|
  (1..43).each { line+=1; file.gets }
  (1..10000).each do |rec|
    # puts line
    start = line
    obj = (1..36).collect { line+=1; file.gets }.join('') + '}'
    begin
      JSON.parse obj
    rescue Exception => e
      errors += 1
      puts "\n\nRecord #{rec} Line #{start}\n\n#{obj}"
      # puts e.message
    end
    break unless file.gets
    line+=1
  end
  puts "\n#{errors} errors"
end

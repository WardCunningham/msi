require 'rubygems'
require 'json'

def load filename
  text = File.read(filename)
  input = JSON.parse(text)
  columns = input['columns']
  data = input['data']
  puts "#{data.length} rows x #{columns.length} columns"
  # puts columns.inspect
  # puts data[0].inspect
  return input
end

@formulas = File.open 'formulas.txt', 'w'
@materials = []
@trouble = 0

def trouble message
  puts "\nTrouble #{@trouble += 1}"
  puts message
end

def stats filename
  input = load filename
  columns = input['columns']
  data = input['data']
  empty = []
  columns.each do |col|
    # next unless col =~ /^Materials?$/
    # next unless col =~ /_Formula$/
    dist = Hash.new(0)
    data.each do |dat|
      code = dat[col].nil? ? "<nil>" : dat[col]
      dist[code ] += 1
    end
    if dist[""]+dist["<nil>"] == data.length
      empty << col 
    else
      puts "\n\n#{col.inspect}"
      dist.keys.sort.each do |key|
        count = dist[key]
        dup = count>1 ? "#{count} x" : ""
        puts "\t#{dup}\t#{key.inspect}"
        @formulas.puts "#{filename}\t#{col}\t#{key}" if key =~ /^=/
      end
    end
    if col =~ /^Materials?$/
      if filename =~ /Tier1/
        @materials = dist.keys.sort
      else
        trouble "Mismatch on keys:\nsurplus: #{(dist.keys.sort - @materials).inspect}\nmissing: #{(@materials - dist.keys.sort).inspect}" unless dist.keys.sort == @materials 
      end
    end
    trouble "Expected singular Material column name" if col =~ /Materials$/
    if col =~ /_Formula$/
      trouble "Local file reference" if dist.keys.inject(false){|s,e| s||=!(e=~/C:/).nil?}
      trouble "Nil or empty formula" if dist['<nil>']+dist['']>0
      trouble "Unexpected quoted operator" if dist.keys.inject(false){|s,e| s||=!(e=~/"</).nil?}
    end
  end
  trouble "Empty columns: #{empty.inspect}" if empty.length > 0
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

Dir.glob 'try9/*.json' do |filename|
  next if filename =~ /Tier3Functions.json$/
  begin
    sep = "--------------------------------------------"
    puts "\n\n#{sep}\n#{filename}\n#{sep}"
    stats filename
  rescue Exception => e
    trouble e.message
  end
end

@formulas.close
puts "\n#{@trouble} trouble"
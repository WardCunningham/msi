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

def stats filename
  input = load filename
  columns = input['columns']
  data = input['data']
  empty = []
  columns.each do |col|
    dist = Hash.new(0)
    data.each do |dat|
      code = dat[col].nil? ? "<nil>" : dat[col]
      dist[code ] += 1
    end
    if dist[""]+dist["<nil>"] == data.length
      empty << col 
    else
      # puts "\n\n#{col.inspect}"
      dist.keys.sort.each do |key|
        count = dist[key]
        dup = count>1 ? "#{count} x" : ""
        puts "\t#{dup}\t#{key.inspect}" # if key =~ /C:/
        @formulas.puts "#{filename}\t#{col}\t#{key}" if key =~ /^=/
      end
    end
  end
  puts "\n\nEmpty columns:\n\n#{empty.inspect}"
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

@trouble = 0
Dir.glob 'try6/*.json' do |filename|
  next if filename =~ /Tier3Functions.json$/
  begin
    sep = "--------------------------------------------"
    puts "#{sep}\n#{filename}\n#{sep}"
    stats filename
  rescue Exception => e
    puts "trouble:"
    puts e.message
    @trouble += 1
  end
end

@formulas.close
puts "#{@trouble} trouble"
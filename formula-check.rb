require 'rubygems'
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

def stats input
  columns = input['columns']
  data = input['data']
  empty = []
  columns.each do |col|
    dist = Hash.new(0)
    data.each do |dat|
      dist[dat[col]] += 1
    end
    if dist[""] == data.length
      empty << col 
    else
      puts "\n\n#{col.inspect}"
      dist.each_pair do |key, count|
        dup = count>1 ? "#{count} x" : ""
        puts "\t#{dup}\t#{key.inspect}"
      end
    end
  end
  puts "\n\nEmpty columns:\n\n#{empty.inspect}"
end

# stats load "try4UTF8/Tier3Functions.json"
# stats load "try4UTF8/Tier3WaterData.json"

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

@tables = {}
@tables["WaterData"] = index "Material", load("try4UTF8/Tier3WaterData.json")
@functions = index "Function Name", load("try4UTF8/Tier3Functions.json")
# puts @functions.inspect


# report possibly trunctated formulas
# load("try4UTF8/Tier3Functions.json")['data'].each do |row|
#   puts "#{row['Function Name']}\t#{row['Function'].length}" if row['Function'].length>30
# end

load("try4UTF8/Tier3Functions.json")['data'].each do |row|
  
  puts "#{row['Function Name']}\t#{row['Function'].length}" if row['Function'].length>30
end


# def eval indent, expr
#   puts "#{indent}#{expr} ---------------"
#   if expr =~ /\+/
#     expr.split(/\*|\+|\-/).each {|token| eval "#{indent}\t", token}
#   elsif expr =~ /=?Tier3WaterData\[(.*?)\]/
#     puts "#{indent}#{$1}"
#   else
#     expr.scan(/\w+/).each do |token|
#       if binding = @functions[token]
#         puts "#{indent} #{token} => #{binding['Function']}"
#         eval "#{indent}\t", binding['Function']
#       else
#         puts "#{indent}#{token}"
#       end
#     end
#   end
# end
# 
# eval "\t", "=WaterYield"

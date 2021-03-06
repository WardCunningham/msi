require 'rubygems'
require 'json'

def check key
  return 'Empty String' if key =~ /^\ *$/
  return 'Trailing Spaces' if key =~ / $/
  return 'Double Spaces' if key =~ /  /
  return 'Leading Spaces' if key =~ /^ /
  return 'No Space After Slash' if key =~ /\/[^ ]/
  return 'No Space Before Slash' if key =~ /[^ ]\//
  return 'Unexpected Asterisk' if key =~ /^ *\*/
  return 'Inexplicit Single Character' if key =~ /^.$/
  # return 'Unexpected ALL-CAPS' unless key =~ /[a-z]/
  return nil
end


def load filename
  text = File.read(filename)
  input = JSON.parse(text)
  columns = input['columns']
  data = input['data']
  puts "#{data.length} rows x #{columns.length} columns"
  columns.each do |key|
    if (msg = check key)
      trouble "#{msg} in Column/Key '#{key}'"
    end
  end
  # puts columns.inspect
  # puts data[0].inspect
  union = {}
  data.each{|row|row.keys.each{|key|union[key]=1}}
  keys = union.keys.to_a - columns
  trouble "fields #{keys.inspect}\nnot in columns #{columns.inspect}" unless keys.length == 0
  return input
end

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
      empty << col unless col =~ / (Notes|Source)$/
    end
    (db, date, raw, table, sufix) = filename.split /[\/\.]/
    short = col.gsub /[^A-Za-z0-9]/, ''
    File.open("#{@try}/Processed/#{table}-#{short}.html", 'w') do |file|
      file.puts "table: <a href=../Raw/#{table}.json>#{table}</a><br>"
      file.puts "column: #{col}<br><pre>"
      # puts "\n\n#{col.inspect}"
      dist.keys.sort.each do |key|
        count = dist[key]
        dup = count>1 ? "#{count} x" : ""
        # puts "\t#{dup}\t#{key.inspect}"
        file.puts "\t#{dup}\t#{key.inspect}"
        @formulas.puts "#{filename}\t#{col}\t#{key}" if key =~ /^=/
      end
    end
    if col =~ /^Materials?$/
      if filename =~ /Tier1/
        @materials = dist.keys.sort
      else
        # trouble "Mismatch on keys:\nsurplus: #{(dist.keys.sort - @materials).inspect}\nmissing: #{(@materials - dist.keys.sort).inspect}" unless (dist.keys.sort == @materials) or (dist.keys.length > 50)
      end
    end
    trouble "Expected singular Material column name" if col =~ /Materials$/
    if col =~ /_Formula$/
      trouble "Local file reference" if dist.keys.inject(false){|s,e| s||=!(e=~/C:/).nil?}
      # trouble "Nil or empty formula" if dist['<nil>']+dist['']>0
      trouble "Unexpected quoted operator" if dist.keys.inject(false){|s,e| s||=!(e=~/"</).nil?}
    end
  end
  # trouble "Empty columns: #{empty.inspect}" if empty.length > 0
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

@try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
@formulas = File.open "#{@try}/Processed/formulas.txt", 'w'

Dir.glob "#{@try}/Raw/*.json" do |filename|
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
# encoding: ISO-8859-1
require 'rubygems'
require 'json'

def random
  (1..16).collect {(rand*16).floor.to_s(16)}.join ''
end

def slug title
  title.gsub(/\s/, '-').gsub(/[^A-Za-z0-9-]/, '').downcase()
end

def clean text
  text.gsub(/’/,"'")
end

def url text
  text.gsub(/(http:\/\/)?([a-zA-Z0-9._-]+?\.(net|com|org|edu)(\/[^ )]+)?)/,'[http:\/\/\2 \2]')
end

def create title
  {'type' => 'create', 'id' => random, 'item' => {'title' => title}}
end 

def paragraph text
  {'type' => 'paragraph', 'text' => text, 'id' => random()}
end

def page title, story
  page = {'title' => title, 'story' => story, 'journal' => [create(title)]}
  File.open("../pages/#{slug(title)}", 'w') do |file| 
    file.write JSON.pretty_generate(page)
  end
end


def odd n
  n&1 == 1
end

def read filename
  lines = []
  File.open(filename, 'r') do |file|
    line = file.readline
    while odd line.count('"') do
      line += file.readline
    end
    lines << line
  end
  lines.join ''
end

# detect lines with odd number of quotes
# Dir.glob('Nike*/*.json') do |filename|
#   puts filename
#   File.foreach(filename) do |line|
#     puts line.length if odd line.count('"')
#   end

boilerplate = paragraph "This data has been imported by script. This text should be replaced with further explainations."
tally = Hash.new 0
errors = 0

def fix key
  key = key.gsub(/ +$/, '')
  key = key.gsub(/  +/, ' ')
  key = key.gsub(/^ +/, '')
  key = key.gsub(/\/ +/, '/')
  key = key.gsub(/\* */, '')
  key = key.gsub(/^SOLID WASTES$/, 'Solid Wastes')
  return key
end

def fixall keys, hash
  result = {}
  keys.each do |key|
    result[fix(key)] = hash[key]
  end
  return result
end

Dir.glob("try3UTF8/*.json") do |filename|
  title = filename.gsub(/\.json$/,'').gsub(/\w+\//,'').gsub(/([a-z0-9])([A-Z])/,'\1 \2')
  puts "\n\n#{title}"
  begin
    text = File.read(filename)
    input = JSON.parse(text)
    puts input['columns'].inspect
    columns = input['columns'].collect{|key| fix(key)}
    units = {}
    columns.each do |key|
      if key =~ / Units$/
        units[key.gsub(/ Units$/,'')] = key
      end
    columns = columns.reject {|key| key =~ / Units$/}
    end
    
    input['columns'].each {|key| tally[key]+=1}
    output = {}
    output['type'] = 'data'
    output['id'] = random
    output['columns'] = columns
    output['data'] = input['data'].collect{|obj| fixall(columns, obj)}
    output['text'] = title
    page title, [output, boilerplate]
  rescue Exception => e
    errors += 1
    puts e.message
  end
end

def check key
  return 'SFX' if key =~ / $/
  return 'DBL' if key =~ /  /
  return 'PFX' if key =~ /^ /
  return 'BRK' if key =~ /\/ /
  return 'AST' if key =~ /^ *\*/
  return 'CAP' unless key =~ /[a-z]/
end

puts "\n\nTally\tColumn Name"
tally.keys.sort.each {|key| puts "#{tally[key]} #{check key}\t'#{key}'#{check(key)? " ==> '#{fix key}'" : ''}"}

puts "\n#{errors} errors"

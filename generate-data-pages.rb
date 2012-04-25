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

# detect lines with odd number of quotes
# Dir.glob('Nike*/*.json') do |filename|
#   puts filename
#   File.foreach(filename) do |line|
#     puts line.length if odd line.count('"')
#   end

boilerplate = paragraph "This data has been imported by script. This text should be replaced with further explainations."

Dir.glob('Nike/*.json') do |filename|
  title = filename.gsub(/\.json$/,'').gsub(/Nike\//,'').gsub(/([a-z0-9])([A-Z])/,'\1 \2')
  puts "#{filename} -- #{title}"
  input = JSON.parse(File.read(filename))
  output = {}
  output['type'] = 'data'
  output['id'] = random
  output['columns'] = input['Columns'].reject{|col| col==""}
  output['data'] = input['data']
  output['text'] = title
  page title, [output, boilerplate]
end


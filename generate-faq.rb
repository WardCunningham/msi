require 'rubygems'
require 'csv'
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

table = CSV.read("NikeMSI_Handout_ProgramParticipation.csv")
head = table.shift
head.shift

index = []
table.each do |row|
  story = []
  title = row.shift
  head.zip(row).each do |question, answer|
    story << paragraph("<b>Q:</b> #{question}<br><b>A:</b> #{clean url answer}")
  end
  page title, story
  index << paragraph("[[#{title}]]")
end
page 'Program Participation Guidelines', index

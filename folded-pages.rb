require 'rubygems'
require 'json'

class Hash
  def my_value
    self['value']
  end
end

class String
  def my_value
    self
  end
end

class NilClass
  def my_value
    ''
  end
end

# Load json from excel

@table = {}
@material = {}

def load filename
  JSON.parse(File.read(filename))
end

def convert! table
  formulas = table['columns'].select{|e|e =~ /_Formula/}
  table['data'] = table['data'].collect do |row|
    formulas.each do |formula|
      column = $1 if formula =~ /^(.*?)_/
      row[column] = {'value' => row[column], 'formula' => row[formula]}
    end
    row.reject {|k,v| formulas.include? k}
  end
  table['columns'] = table['columns'] - formulas
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key].downcase] = row
  end
  return hash
end

def materials
  @material['Tier1MSISummary'].keys.sort
end

def name material
  @material['Tier1MSISummary'][material]['Material']
end

def init
  Dir.glob('try9/*.json') do |filename|
    (prefix, table, sufix) = filename.split /[\/\.]/
    @table[table] = input = load(filename)
    convert! input
    @material[table] = index input['columns'].first, input if (40..50).include? input['data'].length
    puts "#{table.ljust 30} #{input['data'].length} rows x #{input['columns'].length} columns (#{input['columns'].first})"
    puts input['columns']
    puts
  end
end

# Emit pages for federated wiki

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

def data table, caption
  {'type' => 'data', 'text' => caption, 'columns' => table['columns'], 'data' => table['data'], 'id' => random()}
end

def fold text
  {'type' => 'pagefold', 'text' => text, 'id' => random()}
end

def page title, story
  page = {'title' => title, 'story' => story, 'journal' => [create(title)]}
  File.open("../pages/#{slug(title)}", 'w') do |file|
    file.write JSON.pretty_generate(page)
  end
end

def summary
  story = []
  story << data(@table['Tier1MSISummary'], "Tier1 MSI Summary")
  materials.each do |material|
    story << paragraph("[[#{name material}]]")
  end
  page 'Tier1 MSI Summary', story
end

def say story, row, keys
  keys.each do |key|
    value = row[key].my_value
    story << paragraph(value) unless value.empty?
  end
end

def content
  # schema = [
  #   {:table => 'Tier3MaterialData', :fields => [
  #     'Nike MSI Supply Chain Scenario',
  #     'Geographic Location','Data Sources',
  #     'Production Method',
  #     'Raw Material Factor',
  #     'Data Quality Assessment']}
  #   {:fold => {:name => 'chemistry', :story => [
  #     {:table => 'Tier3MaterialData', :fields => [
  #       'Chemistry Exposure Assumptions']}
  #     ]}
  #   {:fold => {:name => 'energy/ghg', :story => [
  #     {:table => 'Tier3MaterialData', :fields => [
  #       'Chemistry Exposure Assumptions']}
  #     ]}
  #   ]

  materials.each do |material|
    story = []
    if row = @material['Tier3MaterialData'][material]
      say story, row, ['Nike MSI Supply Chain Scenario','Geographic Location','Data Sources','Production Method','Raw Material Factor','Data Quality Assessment']
    end
    if row = @material['Tier3Materials'][material]
      say story, row, ['Material Notes', 'Material Sources']
    end
    story << fold("chemistry")
    if row = @material['Tier3MaterialData'][material]
      say story, row, ['Chemistry Exposure Assumptions']
    end
    story << fold("energy/ghg")
    if row = @material['Tier3MaterialData'][material]
      story << paragraph("Energy Scoring Drivers")
      say story, row, ['Energy Scoring Drivers Phase 1','Energy Scoring Drivers Phase 2']
      story << paragraph("GHG Emissions Scoring Drivers")
      say story, row, ['GHG Emissions Scoring Drivers Phase 1','GHG Emissions Scoring Drivers Phase 2']
    end
    page name(material), story
  end
end

init
summary
content

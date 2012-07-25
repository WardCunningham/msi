require 'rubygems'
require 'json'

@trouble = 0
@duptrouble = {}
def trouble message
  return if @duptrouble[message]
  puts "\nTrouble #{@trouble += 1}"
  @duptrouble[message] = 1
  puts message
  # puts caller.inspect
end


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

@tables = {}
@materials = {}

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
  @materials['Tier1MSISummary'].keys.sort
end

def name material
  @materials['Tier1MSISummary'][material]['Material']
end

def init
  @try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
  puts "from #{@try}"
  puts

  Dir.glob("#{@try}/Raw/*.json") do |filename|
    (pf1, pf2, pf3, table, sufix) = filename.split /[\/\.]/
    @tables[table] = input = load(filename)
    convert! input
    @materials[table] = index input['columns'].first, input if (40..50).include? input['data'].length
    puts "#{table.ljust 30} #{input['data'].length} rows x #{input['columns'].length} columns (#{input['columns'].first})"
  end
end

# wiki utilities

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

# journal actions

def create title
  {'type' => 'create', 'id' => random, 'item' => {'title' => title}}
end

# story emiters

def paragraph text
  @story << {'type' => 'paragraph', 'text' => text, 'id' => random()}
end

def data table, caption
  @story << {'type' => 'data', 'text' => caption, 'columns' => table['columns'], 'data' => table['data'], 'id' => random()}
end

def fold text
  @story << {'type' => 'pagefold', 'text' => text, 'id' => random()}
  yield
end

def page title
  @story = []
  yield
  page = {'title' => title, 'story' => @story, 'journal' => [create(title)]}
  File.open("../pages/#{slug(title)}", 'w') do |file|
    file.write JSON.pretty_generate(page)
  end
end

# custom emiters

@record = nil

def table name
  @table = @materials[name]
  @table_name = name
  # trouble "No record for '#{@material}' in table '#{name}'" if @table[@material].nil?
  yield
end

def record title
  @record = {}
  yield
  data({'columns' => @record.keys, 'data' => [@record]}, title)
  @record = nil
end

def dataset title
  @dataset = materials.inject({}) { |hash, key| hash[key]={'Material' => key}; hash }
  yield
  values = @dataset.values
  data({'columns' => values.first.keys, 'data' => values}, title)
  @dataset = nil
end

def field column
  return @dataset.each {|key,value| value[column] = @table[key][column]||''} if !@dataset.nil?
  row = @table[@material]
  trouble "No record for '#{@material}' in table '#{@table_name}'" if row.nil?
  return @record[column] = row[column] if !@record.nil?
  value = row.nil? ? "N/A" : row[column].my_value
  paragraph value unless value.empty?
end

# content generators

def summary
  page 'Tier1 MSI Summary' do
    dataset 'Tier1 MSI Summary' do
      table 'Tier1MSISummary' do
        field 'Material'
        field 'Total Score'
        field 'Rank'
        field 'Energy/GHG Emissions Intensity Total'
        field ' Chemistry Total'
        field 'Water/Land Intensity Total'
        field 'Physical Waste Total'

      end
    end
    materials.each do |material|
      paragraph "[[#{name material}]]"
    end
  end
end

def content
  materials.each do |material|
    @material = material
    page name(material) do
      record "Material Summary" do
        table 'Tier1MSISummary' do
          field 'Material'
          field 'Total Score'
          field 'Energy/GHG Emissions Intensity Total'
          field ' Chemistry Total'
          field 'Water/Land Intensity Total'
          field 'Physical Waste Total'
        end
      end
      table 'Tier3MaterialData' do
        field 'Nike MSI Supply Chain Scenario'
        field 'Geographic Location'
        field 'Data Sources'
        field 'Production Method'
        field 'Raw Material Factor'
        field 'Data Quality Assessment'
      end
      table'Tier3Materials' do
        field 'Material Notes'
        field 'Material Sources'
      end

      fold 'chemistry' do
        record "Chemistry" do
          table 'Tier1MSISummary' do
            field 'Acute Toxicity'
            field 'Chronic Toxicity'
            field 'Reproductive/Endocrine Disrupter Toxicity'
            field 'Carcinogenicity '
          end
        end
        table 'Tier3MaterialData' do
          field 'Chemistry Exposure Assumptions'
        end
      end

      fold 'energy/ghg' do
        record "Energy/GHG Intensity" do
          table 'Tier1MSIRawData' do
            field 'Energy Intensity'
            field 'GHG Emissions Intensity'
          end
        end
        table 'Tier3MaterialData' do
          paragraph 'Energy Scoring Drivers:'
          field 'Energy Scoring Drivers Phase 1'
          field 'Energy Scoring Drivers Phase 2'
          paragraph 'GHG Emissions Scoring Drivers:'
          field 'GHG Emissions Scoring Drivers Phase 1'
          field 'GHG Emissions Scoring Drivers Phase 2'
        end
      end

      fold 'water/land' do
        record "Water/Land Intensity" do
          table 'Tier1MSISummary' do
            field 'Water Intensity'
            field 'Land Intensity'
          end
        end
        table 'Tier3MaterialData' do
          paragraph 'Water Scoring Drivers:'
          field 'Water Scoring Drivers Phase 1'
          field 'Water Scoring Drivers Phase 2'
          paragraph 'Land Scoring Drivers:'
          field 'Land Scoring Drivers'
        end
      end

      fold 'physical waste' do
        record "Physical Waste" do
          table 'Tier1MSISummary' do
            field 'Recycled/Compostable waste'
            field 'Municipal Solid Waste'
            field 'Mineral waste'
            field 'Hazardous Waste'
            field 'Industrial waste'
          end
        end
        paragraph 'No physical waste documentation at present.'
      end

    end
  end
end

init
summary
content

puts "\n#{@trouble} trouble"
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

def convert! name, table
  sufix = 'Formula'
  targets = {}
  columns = table['columns']
  columns.each do |col|
    if col =~ /(.+?)_#{sufix}/
      candidates = columns.select {|e| e==$1}
      if candidates.length == 1
        targets[col] = candidates.first
      else
        trouble "Can't find column for #{col} in #{name}"
      end
    end
  end
  table['data'] = table['data'].collect do |row|
    targets.each do |formula, target|
      row[target] = {'value' => row[target], sufix.downcase => row[formula]}
    end
    row.reject {|k,v| targets.include? k}
  end
  table['columns'] = table['columns'] - targets.keys
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

def materials
  @materials['Tier1MSISummary'].keys.sort
end

def name material
  @materials['Tier1MSISummary'][material]['Material']
end

def rank material
  @materials['Tier1MSISummary'][material]['Rank'].my_value
end

def score material
  @materials['Tier1MSISummary'][material]['Total Score'].my_value
end

def init
  @try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
  puts "from #{@try}"
  puts

  Dir.glob("#{@try}/Raw/*.json") do |filename|
    (pf1, pf2, pf3, table, sufix) = filename.split /[\/\.]/
    @tables[table] = input = load(filename)
    convert! table, input
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

def domain text
  text.gsub(/((https?:\/\/)(www\.)?([a-zA-Z0-9._-]+?\.(net|com|org|edu|us|cn|dk|au))(\/[^ );]*)?)/,'[\1 \4]')
end

def aspect text
  aspects = 'Geographic location|Data sources|Production method|Kg raw material required for 1 kg yarn/subcomponent|Data Quality Assessment|Phase 1|Phase 2'
  text.gsub /(#{aspects}:)/, '<b>\1</b>'
end

# journal actions

def create title
  {'type' => 'create', 'id' => random, 'item' => {'title' => title}, 'date' => Time.now.to_i*1000}
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
  return if value.empty?
  paragraph domain aspect value
end

# content generators

def summary
  page 'Materials Summary' do
    dataset 'Materials Summary' do
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
    paragraph "We summarize the materials both as a dataset and as links to data sheets for each materials."
    paragraph "From run of #{Time.now.strftime '%m-%d %H:%M'}<br>Data labeled #{@try}."
    paragraph "Try visualizing with the [[Material Scatter Chart]]."
    paragraph "See also [[Materials by Rank]]."
    paragraph "<h3>Materials Alphabetically"
    materials.each do |material|
      paragraph "[[#{name material}]] ranked #{rank material}"
    end
  end
  page 'Materials by Rank' do
    paragraph 'We order the materials by their rank based on total score.'
    paragraph "From run of #{Time.now.strftime '%m-%d %H:%M'}<br>Data labeled #{@try}."
    paragraph 'See also [[Materials Summary]] in alphabetical order.'
    paragraph '<h3>Materials by Rank'
    rank = 0
    materials.sort{|a,b|rank(a).to_i <=> rank(b).to_i}.each do |material|
      rank += 1
      paragraph "#{rank}. [[#{name material}]] scored #{(score(material).to_f*10).round/10.0}"
    end
  end
end

def content
  materials.each do |material|
    # puts "'#{material}'"
    @material = material
    page name(material) do
      record "Material Summary" do
        table 'Tier1MSISummary' do
          field 'Material'
          field 'Total Score'
          field 'Energy/GHG Emissions Intensity Total'
          field 'Chemistry Total'
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
      table'Tier3MaterialData' do
        field 'Material Notes'
        field 'Material Sources'
      end
      paragraph 'Try visualizing with the [[D3 Radar Chart]].'

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

def workbook
  page 'Workbook Summary' do
    paragraph "These tables have been extracted from the [[Nike MSI Workbook]] through a Visual Basic program."
    paragraph "Related columns have been collapsed into single columns containing value objects with aditional fields for units, notes and formulas."
    paragraph "This and related data can be found organized by material in the [[Materials Summary]]."
    paragraph "From run of #{Time.now.strftime '%m-%d %H:%M'}<br>Data labeled #{@try}."
    paragraph "<h3>Material Tables"
    @tables.keys.sort.each do |name|
      input = @tables[name]
      next unless input['data'].length == 44
      paragraph "[[#{name}]] #{input['data'].length} rows x #{input['columns'].length} columns"
    end
    paragraph "<h3>Other Tables"
    @tables.keys.sort.each do |name|
      input = @tables[name]
      next if input['data'].length == 44
      paragraph "[[#{name}]] #{input['data'].length} rows x #{input['columns'].length} columns"
    end
  end
  @tables.keys.each do |name|
    page name do
      input = @tables[name]
      data input, name
      paragraph "Table #{name} as exported from the Nike MSI Excel Workbook."
      paragraph "From run of #{Time.now.strftime '%m-%d %H:%M'}<br>Data labeled #{@try}."
      paragraph "See [[Workbook Summary]] for other tables."
      paragraph "<h3>Columns"
      paragraph "For each column we list the most frequent values and the count of various other values (denoted as ...)"
      input['columns'].each do |col|
        dist = Hash.new(0)
        input['data'].each do |dat|
          code = dat[col].nil? ? "<nil>" : dat[col].my_value
          dist[code] += 1
        end
        report = dist.keys.select{|a|dist[a]>1}.sort{|a,b|dist[b]<=>dist[a]}.collect do |key|
          count = dist[key]
          dup = count>1 ? "#{count}x" : ""
          "#{dup}#{key.inspect}"
        end
        various = dist.keys.select{|a|dist[a]==1}
        if various.length > 0
          if various.length > 4
            report << "#{various.length}x ..."
          else
            report << various.collect{|key|key.inspect}
          end
        end
        paragraph "<b>#{col}</b><br>#{report.join ', '}"
      end
    end
  end
end

init
summary
content
workbook

puts "\n#{@trouble} trouble"
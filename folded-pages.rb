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

# load json from excel -- methods here reflect source file and content organization

@tables = {}
@materials = {}

# Additional Column Conventions (to be touched up after 8-25-12 version)
# these column heading conventions apply to Tier3(Water|Land|GHG|Energy)Data

# Total
# Total Units
# Total Notes

# Water Finishing (Total|Subtotal)
# Water Finishing Units
# Water Finishing Notes

# Bleaching
# Bleaching Units
# Bleaching Notes

# Fabric
# Fabric Add on

def convert! name, table
  ['Formula'].each do |sufix|
    targets = {}
    columns = table['columns']
    columns.each do |col|
      if col =~ /(.+?)( |_)#{sufix}$/
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
        row[target] = {'value' => row[target], sufix.downcase => row[formula]} if row[formula]
      end
      row.reject {|k,v| targets.include? k}
    end
    table['columns'] = table['columns'] - targets.keys
  end
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

def load
  @try = Dir.glob('db/*-*-*').max_by {|e| File.mtime(e)}
  puts "from #{@try}"
  puts

  Dir.glob("#{@try}/Raw/*.json") do |filename|
    (pf1, pf2, pf3, table, sufix) = filename.split /[\/\.]/
    @tables[table] = input = JSON.parse(File.read(filename))
    convert! table, input
    @materials[table] = index input['columns'].first, input if (40..50).include? input['data'].length
    puts "#{table.ljust 30} #{input['data'].length} rows x #{input['columns'].length} columns (#{input['columns'].first})"
  end
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

def empty string
  return true unless string
  string.strip == ''
end

def known obj
  val = obj.my_value
  empty(val) ? '-' : val
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

# wiki page and components -- methods here are named after wiki json elements

def bold text
  aspects = 'Geographic location|Data sources|Production method|Kg raw material required for 1 kg yarn/subcomponent|Data Quality Assessment|Phase 1|Phase 2'
  text.gsub /(#{aspects}:)/, '<b>\1</b>'
end

def external text
  text.gsub(/((https?:\/\/)(www\.)?([a-zA-Z0-9._-]+?\.(net|com|org|edu|us|cn|dk|au))(\/[^ );]*)?)/,'[\1 \4]')
end

def guid
  (1..16).collect {(rand*16).floor.to_s(16)}.join ''
end

def slug title
  title.gsub(/\s/, '-').gsub(/[^A-Za-z0-9-]/, '').downcase()
end

def create title, story
  @certificate ||= "From export: #{@try}, git sha-1: #{`git rev-parse HEAD`.chomp}"
  item = {'title' => title, 'story' => story}
  {'type' => 'create', 'id' => guid, 'item' => item, 'date' => Time.now.to_i*1000, 'certificate' => @certificate}
end

def paragraph text
  @story << {'type' => 'paragraph', 'text' => text, 'id' => guid}
end

def data table, caption
  @story << {'type' => 'data', 'text' => caption, 'columns' => table['columns'], 'data' => table['data'], 'id' => guid}
end

def fold text
  @story << {'type' => 'pagefold', 'text' => text, 'id' => guid}
  yield
end

def method lines, options={}
  @story << {'type' => 'method', 'text' => lines.join("\n"), 'id' => guid}.merge(options) unless lines.empty?
end

def page title
  @story = []
  yield
  path = "../archive/#{slug(title)}"
  action = create title, @story
  begin
    # raise "skip history as if there were none"
    page = JSON.parse File.read("../archive/#{slug(title)}")
    page['story'] = @story
    page['journal'] ||= []
    page['journal'] << action
  rescue
    page = {'title' => title, 'story' => @story, 'journal' => [action]}
  end
  File.open("../pages/#{slug(title)}", 'w') do |file|
    file.write JSON.pretty_generate(page)
  end
end

# domain lanuage emitters -- methods here are terms used in the content description language

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

def total result, op='SUM'
  @calculate = []
  yield
  @calculate << "#{op} #{result}"
  method @calculate
  @calculate = nil
end

def field column
  # handle dataset
  return @dataset.each {|key,value| value[column] = @table[key][column]||''} unless @dataset.nil?
  row = @table[@material]
  trouble "No record for '#{@material}' in table '#{@table_name}'" if row.nil?
  # handle record
  return @record[column] = row[column] unless @record.nil?
  value = row.nil? ? "N/A" : row[column].my_value
  # puts [value, column, row].inspect if 'Acrylic fabric' == name(@material) && column == 'Energy Intensity'
  # handle calculate
  return @calculate << "#{known value} #{column}" unless @calculate.nil?
  # handle paragraph
  return if value.empty?
  paragraph external bold value
end

def given value, label=''
  @calculate << "#{value} #{label}"
end

def recall key
  @calculate << " #{key}"
end

# content interpreters -- methods here have noun-phrase names

def table_column_values name, table, col
  dist = Hash.new(0)
  table['data'].each do |dat|
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
  report
end

def table_column_formulas name, table, col
  formulas = Hash.new(0)
  count = 0
  table['data'].each do |dat|
    next unless dat[col]['formula']
    formulas[dat[col]['formula']] += 1
    count += 1
  end
  unless formulas.empty?
    if formulas.size > 1 or formulas.first.last < table['data'].size
      paragraph "[[#{name}]]" unless @last_table_name == name
      items = ["<b>#{col}</b>"]
      if (absent = table['data'].size - count) > 0
        items << "#{absent} x absent"
      end
      formulas.each do |key, value|
        items << "#{value} x #{key.length > 45 ? key[0..42]+'...' : key}"
      end
      paragraph items.join('<br>')
      @last_table_name = name
    end
  end
end

def chemistry_substance row, category

  (short_category, long_category) = case category
  	when /Acute/i then ['Acute', 'Acute Toxicity']
  	when /Chronic/i then ['Chronic', 'Chronic Toxicity']
  	when /Carcinogen/i then ['Carcinogen', 'Carcinogenicity']
  	when /Reproductive/i then ['ReproEndo', 'Reproductive / Endocrine Disrupter Toxicity']
  	else trouble "Can't understand #{category}"
  end
  paragraph "#{row['Substance']} Phase #{row['Phase']} #{short_category} score:"
  processes = ['Fiber / Subcomponent', 'Refinery Processing to Pellet', 'Textile / Component']
  info = []
  processes.each do |process|
    info << "#{row[process].my_value} #{process}" if row[process] != ''
  end
  info << "FIRST Exposure"
  info << "#{known row[short_category]} Raw"
  info << "LOOKUP Tier3ExposurePercentages"
  weightTable = @tables['Tier3WeightTable']['data']
  points = weightTable.find{|r| r['SubType'] == long_category}['Points']
  info << "#{known points} #{long_category} Points"
  info << "PRODUCT #{row['Substance']}"
  method info, {:silent=>true}
end

def chemistry_phase category, phase
  chemistryData = @tables['Tier3ChemistryData']['data']
  rows = chemistryData.select{|row|row['Material']==name(@material)&&row['Phase']==phase}
  trouble "can't find any chemistry data for #{[@material, category, phase, rows.size].inspect}" if rows.size < 1
  rows.each do |row|
    # puts (['Material','Substance','Phase',category].collect{|k|row[k].my_value}.inspect) if row['Material'] == 'Glass fiber'
    # value = row[category].my_value
    # next if empty(value)
    chemistry_substance row, category
    @calculate << " #{row['Substance']}"
  end
end

def chemistry_toxicity indicator, short
  paragraph "<b>#{indicator}"
  paragraph "We enumerate the stubstances that have an impact on #{indicator} in phase 1 processing. Later we will choose the worst case phase 1 driver. See [[Why Phases and Drivers]]."
  total "#{indicator} (phase 1 min)", 'MINIMUM' do
    chemistry_phase "Weighted #{short}", '1'
    paragraph "We choose the minimum (worst case) #{indicator} for phase 1 substances as one driver for the score."
  end
  paragraph "This completes the phase 1 #{indicator} calculation."
  paragraph "We enumerate the stubstances that have an impact on #{indicator} in phase 2 processing. Later we will choose the worst case phase 2 driver. See [[Why Phases and Drivers]]."
  total "#{indicator} (phase 2 min)", 'MINIMUM' do
    chemistry_phase "Weighted #{short}", '2'
    paragraph "And we choose the minimum (worst case) #{indicator} for phase 2 substances as the other driver."
  end
  paragraph "We average the drivers from both phases to contribute a single #{indicator} metric."
  total indicator, 'AVERAGE' do
    recall "#{indicator} (phase 1 min)"
    recall "#{indicator} (phase 2 min)"
  end
  paragraph "This completes the #{indicator} score calculation. We'll average this with other indicators at the end of the chemistry section."
end

def mass_used_label row
  if empty(row['Phase Name'])
    "Mass used for Phase #{row['Phase']}"
  else
    "Mass used for #{row['Phase Name']}"
  end
end

def transport type, scenario
  transport = @tables['Tier3TransportScenario']['data']
  trow = transport.find {|trow| trow['Scenario'] == scenario}
  if trow
    return trow[type].my_value
  else
    return 0
  end
end

def electric_grid location
  table = @tables['Tier3ElectricGridData']['data']
  trow = table.find {|trow| trow['Location'] == location}
  if trow
    return trow['kg CO2 / MJ'].my_value
  else
    return 0
  end
end

def finishing type, row
  info = []
  steps = case type
  when 'Water' then ['Greige / Other', 'Desizing', 'Scouring / Washing', 'Bleaching', 'Fulling', 'Mercerization', 'Dyeing', 'Printing', 'Rinsing / Finishing']
  when 'Energy' then ['Greige / Other', 'Dyeing and Finishing', 'Other']
  else
    trouble "Don't know type #{type}"
  end
  steps.each do |col|
    if empty(row[col].my_value)
      info << "0 #{col}"
    else
      info << "#{row[col].my_value} #{col}"
    end
  end
  info << "SUM #{type} Finishing Total"
  method info
end

def ghg_greige type, row
  paragraph "Proportion GHG for Greige between Energy Grid and Fossil Fuel."
  info = []
  info << " Greige / Other"
  info << "#{electric_grid row['Textile Location']} kg CO2 / MJ"
  info << "#{row['Calculate Greige']=='True' ? 0.800 : 0.333} proportion"
  info << "PRODUCT Greige Energy Grid"
  method info

  info = []
  if row['Calculate Greige'] == 'True' and name(@material) =~ / fabric$/i
    info << " Greige / Other"
    info << "0.065 Fossil Fuel CO2/MJ"
    info << "#{row['Calculate Greige']=='True' ? 0.200 : 0.666} proportion"
    info << "PRODUCT Greige Fossil Fuel"
  else
    info << "0 Greige Fossil Fuel"
  end
  method info
end

def ghg_dyeing_and_finishing type, row
  paragraph "Proportion GHG for Dyeing and Finishing between Energy Grid and Fossil Fuel."
  info = []
  info << " Dyeing and Finishing"
  info << "#{electric_grid row['Textile Location']} kg CO2 / MJ"
  info << "0.333 proportion"
  info << "PRODUCT Dyeing and Finishing Energy Grid"
  method info

  info = []
  if row['Calculate Dyeing Finishing'].my_value == 'True' and name(@material) =~ / fabric$/i
    info << " Dyeing and Finishing"
    info << "0.065 Fossil Fuel CO2/MJ"
    info << "0.666 proportion"
    info << "PRODUCT Dyeing and Finishing Fossil Fuel"
  else
    info << "0 Dyeing and Finishing Fossil Fuel"
  end
  method info
end

def ghg_finishing type, row

  ghg_greige type, row
  ghg_dyeing_and_finishing type, row
  paragraph "Now we sum for greige, transport, dyeing and finishing."
  info = []
  info << " Greige Energy Grid"
  info << " Greige Fossil Fuel"
  info << "#{transport 'GHG', row['Greige Transport']} Greige Transport"
  info << " Dyeing and Finishing Energy Grid"
  info << " Dyeing and Finishing Fossil Fuel"
  info << "SUM #{type} Finishing Total"
  method info

end

def processing type, row
  process = @tables['Tier3ProcessInformation']['data']
  info = []
  info << "1 Kg Output"
  rows = process.select{|row| row['Material'] == name(@material) && row['Process Type'] == type}.sort_by{|row| row['Phase']}.reverse
  paragraph "We compute the mass required at each phase to yield one Kg of material after all phases."
  paragraph "Note: adjustment is allocation for Phase 0, material loss % for other Phases."
  rows.each do |row|
    paragraph "#{row['Phase']} (#{row['Phase Name']}) #{row['Material loss % or Allocation %']} loss #{row['Kg per Unit']} Kg/Unit"
    if row['Phase'] == '0'
      loss_adjustment = row['Material loss % or Allocation %']
    else
      loss_adjustment = 1/(1-row['Material loss % or Allocation %'].to_f)
    end
    info << "#{loss_adjustment} adjustment for loss in #{row['Phase Name']}"
    info << "PRODUCT Mass Input Phase #{row['Phase']}"
  end
  method info
  paragraph "Now, knowing the input required of each phase, we compute mass related quantities."
  rows.each do |row|
    info = []
    default = 0
    info << "#{empty(row['Kg per Unit']) ? default : row['Kg per Unit']} Kg per Unit for #{row['Phase Name']}"
    info << " Mass Input Phase #{row['Phase']}"
    info << "PRODUCT #{mass_used_label row}"
    if type == 'Energy' && !empty(row['Transport Scenario'])
      transport = @tables['Tier3TransportScenario']['data']
      trow = transport.find {|trow| trow['Scenario'] == row['Transport Scenario']}
      info << "#{trow[type].my_value} #{trow['Description']} Transport"
      info << "SUM #{mass_used_label row}"
    end
    method info
  end
  info = []
  paragraph "Now we add up the mass used in each phase."
  rows.each do |row|
    info << " #{mass_used_label row}"
  end
  info << "SUM #{type} Process Total"
  method info
end

def ghg_processing type, xrow
  process = @tables['Tier3ProcessInformation']['data']
  rows = process.select{|row| row['Material'] == name(@material) && row['Process Type'] == 'Energy'}.sort_by{|row| row['Phase']}.reverse
  paragraph "Now, for every phase."
  paragraph "WIP ghg processing"
  rows.each do |row|
    # paragraph "calculate ghg: #{row['Calculate GHG']}, designated: #{row['Designated Value']}, phase: #{row['Phase']}, grid: #{row['Electric Grid'].my_value}, fossil: #{row['Fossil Fuels'].my_value}"
    paragraph "Phase #{row['Phase']}, Grid Source: '#{row['GHG Gridsource'].my_value}'"


    info = []
    info2 = []
    info_sub = []
    if !empty(row['Designated Value'])
      info_sub << "#{row['Designated Value'].my_value} #{mass_used_label row}"
    else
      if row['Calculate GHG'] == 'True'
        info << " #{mass_used_label row}"
        info << "-#{transport 'Energy', row['Transport Scenario']} Energy Transport"
        info << "SUM Mass Without Transport (Phase #{row['Phase']})"
        info << "#{electric_grid row['GHG Gridsource'].my_value} Electric Grid"
        info << "#{row['Electric Grid Multiplier'].my_value} Electric Grid Multiplier"
        info << "PRODUCT Electric Grid (Phase #{row['Phase']})"

        info2 << " Mass Without Transport (Phase #{row['Phase']})"
        info2 << "0.075 Diesel Kg CO2 / MJ"
        info2 << "#{row['Fossil Fuel Multiplier'].my_value} Fossil Fuel Multiplier"
        info2 << "PRODUCT Fossil Fuels (Phase #{row['Phase']})"

      else
        info << "0 Electric Grid (Phase #{row['Phase']})"
        info2 << "0 Fossil Fuels (Phase #{row['Phase']})"
      end
      info_sub << " Electric Grid (Phase #{row['Phase']})"
      info_sub << " Fossil Fuels (Phase #{row['Phase']})"
      info_sub << "#{transport 'GHG', row['GHG Transport Scenario']} GHG Transport"
      info_sub << "SUM #{mass_used_label row}"
    end
    method info
    method info2
    method info_sub
  end
  paragraph "End WIP"

  info = []
  paragraph "Now we add up the GHG in Kg/MJ in each phase."
  rows.each do |row|
    info << " #{mass_used_label row}"
  end

  info << "-#{xrow['Carbon Sequestration'].my_value} Carbon Sequestration"
  info << "SUM #{type} Process Total"
  method info
end

def raw_score type, row
  info = []
  if empty(row['Total']['formula'])
    info << "#{row['Total'].my_value} #{type} Raw Score"
  else
    finishing type, row
    processing type, row
    paragraph "Now sum the finishing and processing"
    info << " #{type} Process Total"
    # Feedstock energy
    if type == 'Energy'
      info << "#{row['Feedstock']} Feedstock"
      info << "SUM"
    end
    if name(@material) =~ / fabric$/i
      info << "1.02 Fabric Add On"
      info << "PRODUCT Adjusted #{type} Processing Total"
    end
    info << " #{type} Finishing Total"
    info << "SUM #{type} Raw Score"
  end
  method info
end

def ghg_raw_score type, row
  info = []
  if empty(row['Total']['formula'])
    info << "#{row['Total'].my_value} #{type} Raw Score"
  else
    ghg_finishing type, row
    ghg_processing type, row
    paragraph "Now sum the finishing and processing"
    info << " #{type} Process Total"
    # Feedstock energy
    if type == 'Energy'
      info << "#{row['Feedstock']} Feedstock"
      info << "SUM"
    end
    if name(@material) =~ / fabric$/i
      info << "1.02 Fabric Add On"
      info << "PRODUCT Adjusted #{type} Processing Total"
    end
    info << " #{type} Finishing Total"
    info << "SUM #{type} Raw Score"
  end
  method info
end


def intensity type, row
  if type == 'GHG'
    ghg_raw_score type, row
    long = 'GHG Emissions'
  else
    raw_score type, row
    long = type
  end
  paragraph "And apply the appropriate polynomial"
  info = []
  info << " #{type} Raw Score"
  info << "POLYNOMIAL #{long} Intensity"
  weightTable = @tables['Tier3WeightTable']['data']
  points = weightTable.find{|row| row['SubType'] == "#{long} Intensity"}['Points']
  info << "#{known points} #{"#{type} Intensity"} Points"
  info << "PRODUCT #{"#{long} Intensity"}"
  method info
end

def water_intensity
  paragraph "<b> Water"
  water = @tables['Tier3WaterData']['data']
  row = water.find {|row| row['Material'] == name(@material)}
  intensity 'Water', row
end

def energy_intensity
  paragraph "<b> Energy"
  data = @tables['Tier3EnergyData']['data']
  row = data.find {|row| row['Material'] == name(@material)}
  intensity 'Energy', row
end

def ghg_intensity
  paragraph "<b> GHG"
  data = @tables['Tier3GHGData']['data']
  row = data.find {|row| row['Material'] == name(@material)}
  intensity 'GHG', row
end

def land_intensity
  paragraph "<b> Land"
  info = []
  land = @tables['Tier3LandData']['data']
  row = land.find {|row| row['Material'] == name(@material)}

  paragraph "We specify a quantitity and apply the appropriate polynomial"
  info = []
  info << "#{row['Total']} Raw Land Data"
  info << "POLYNOMIAL Land Intensity"
  weightTable = @tables['Tier3WeightTable']['data']
  points = weightTable.find{|row| row['SubType'] == "Land Intensity"}['Points']
  info << "#{known points} #{"Land Intensity"} Points"
  info << "PRODUCT #{"Land Intensity Score"}"
  method info
end

def physical_waste indicator, short
  paragraph "<b>#{indicator}"
  info = []
  other = @tables['Tier3OtherPhysicalWaste']['data']
  estimate = other.find {|row| row['Material'] == name(@material)}
  if estimate
    info << "#{estimate[indicator].to_f / 100} #{indicator} Percentage"
  else
    waste = @tables['Tier3PhysicalWaste']['data']
    sources = waste.select {|row| row['Material'] == name(@material) && row['Waste Type'] == short}
    sources.each do |source|
      info << "#{source['Totals'].my_value} #{source['Solid Wastes']}" if source['Totals'].my_value != '0'
    end
    info << "SUM"
    info << "POLYNOMIAL #{indicator}"
  end
  weightTable = @tables['Tier3WeightTable']['data']
  points = weightTable.find{|row| row['SubType'] == indicator}['Points']
  info << "#{known points} #{indicator} Points"
  info << "PRODUCT #{indicator}"
  method info, {:silent=>true}
end

# page generators -- methods here have verb-phrase names

def list_all_materials
  page 'Materials Summary' do
    dataset 'Materials Summary' do
      table 'Tier1MSISummary' do
        field 'Material'
        field 'Total Score'
        field 'Rank'
        field 'Energy / GHG Emissions Intensity Total'
        field 'Chemistry Total'
        field 'Water / Land Intensity Total'
        field 'Physical Waste Total'
      end
    end
    paragraph "We summarize the materials both as a dataset and as links to data sheets for each materials."
    paragraph "From run of #{Time.now.strftime '%m-%d %H:%M'}<br>Data labeled #{@try}."
    paragraph "Try visualizing with the [[Material Scatter Chart]]."
    paragraph "See also [[Materials by Rank]]."
    paragraph "<h3>Fabrics Alphabetically"
    materials.each do |material|
      paragraph "[[#{name material}]] ranked #{rank material}" if name(material) =~ / fabric/
    end
    paragraph "<h3>Other Materials Alphabetically"
    materials.each do |material|
      paragraph "[[#{name material}]] ranked #{rank material}" unless name(material) =~ / fabric/
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

def describe_each_material
  materials.each do |material|
    # puts "'#{material}'"
    @material = material
    page name(material) do
      record "Material Summary" do
        table 'Tier1MSISummary' do
          field 'Material'
          field 'Total Score'
          field 'Energy / GHG Emissions Intensity Total'
          field 'Chemistry Total'
          field 'Water / Land Intensity Total'
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
        field 'Material Notes'
        field 'Material Sources'
      end
      paragraph 'Try visualizing with the [[D3 Radar Chart]].'

      fold 'reference data' do

        name = "Tier3ExposurePercentages"
        data @tables[name], "[[#{name}]]"
        paragraph 'We cache a copy of the allocated percentages here to simplify our computations for the moment.'
        paragraph 'You can substitute different allocations by dragging a different table here.'
        paragraph 'You can use one table for all materials by removing this table and providing an alternative to the left.'

        name = "Tier3Polynomials"
        data @tables[name], "[[#{name}]]"
        paragraph 'We also cache a copy of the ranged polynomial coeficients we will use to translate measurements and estimates to scores.'
      end

      fold 'chemistry' do

        paragraph 'We start with the Chemistry Total as computed in the excel workbook. We will be checking these with the client-side computations as we go along'
        total 'Chemistry Total' do
          table 'Tier1MSISummary' do
            field 'Acute Toxicity'
            field 'Chronic Toxicity'
            field 'Reproductive / Endocrine Disrupter Toxicity'
            field 'Carcinogenicity'
          end
        end

        paragraph 'We will weight scores by percentages based on the exposure and the raw toxicity of each substance.'
        chemistry_toxicity 'Acute Toxicity', 'Acute'
        chemistry_toxicity 'Chronic Toxicity', 'Chronic'
        chemistry_toxicity 'Carcinogenicity', 'carcinogen'
        chemistry_toxicity 'Reproductive / Endocrine Disrupter Toxicity', 'Reproductive'

        paragraph 'Now we compute four toxicity and carcinogenicity chemistry factors for materials from substances employed in their manufacture. These are allocated to and talled separately for each phase. See [[Manufacturing Phases]].'
        paragraph '<b>Chemistry Total'
        total 'Chemistry Total' do
          table 'Tier1MSISummary' do
            recall 'Acute Toxicity'
            recall 'Chronic Toxicity'
            recall 'Reproductive / Endocrine Disrupter Toxicity'
            recall 'Carcinogenicity'
          end
        end

        table 'Tier3MaterialData' do
          field 'Chemistry Exposure Assumptions'
        end
      end

      fold 'energy/ghg' do
        energy_intensity
        ghg_intensity
        paragraph "And sum Energy and GHG Emissions."
        total 'Energy / GHG Emissions Intensity Total' do
          table 'Tier1MSISummary' do
            recall 'Energy Intensity'
            recall 'GHG Emissions Intensity'
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
        water_intensity
        land_intensity
        paragraph "Now we sum the scores for both water and land."
        total 'Water / Land Intensity Total' do
          table 'Tier1MSISummary' do
            recall 'Water Intensity Score'
            recall 'Land Intensity Score'
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
        physical_waste 'Recyclable / Compostable Waste', 'Recyclable/Compostable'
        physical_waste 'Municipal Solid Waste', 'Municipal Solid Waste'
        physical_waste 'Mineral Waste', 'Mineral'
        physical_waste 'Hazardous Waste', 'Hazardous'
        physical_waste 'Industrial Waste', 'Industrial'
        paragraph "<b> Physical Waste Total"
        total 'Physical Waste Total' do
          table 'Tier1MSISummary' do
            recall 'Recyclable / Compostable Waste'
            recall 'Municipal Solid Waste'
            recall 'Mineral Waste'
            recall 'Hazardous Waste'
            recall 'Industrial Waste'
          end
        end
        paragraph 'No physical waste documentation at present.'
      end

      fold 'totals' do
        total 'Total Score' do
          recall 'Chemistry Total'
          recall 'Energy / GHG Emissions Intensity Total'
          recall 'Water / Land Intensity Total'
          recall 'Physical Waste Total'
        end
      end
    end
  end
end

def describe_source_tables
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
        report = table_column_values name, input, col
        paragraph "<b>#{col}</b><br>#{report.join ', '}"
      end
    end
  end
  page 'Workbook Formulas' do
    paragraph "We list columns that have formulas that vary between rows of a given table. This indicates a need for special handling in the workbook to wiki page translation."
    paragraph "See [[Workbook Summary]] for a complete list of tables."
    paragraph "When a formula is listed as <i>absent</i> that indicates that a calculation has been overridden with a specific value, possibly blank or null."
    @tables.keys.sort.each do |name|
      input = @tables[name]
      input['columns'].each do |col|
        table_column_formulas name, input, col
      end
    end
  end
end

load
list_all_materials
describe_each_material
describe_source_tables

puts "\n#{@trouble} trouble"
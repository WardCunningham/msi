require 'rubygems'
require 'json'
require 'parser2'

class Calculate

  def initialize
    @parser = Parser.new
    @trouble = 0
    @tables = {}
    @columns = {}
    @formulas = {}
    
    Dir.glob 'try6/*.json' do |filename|
      next if filename =~ /Tier3Functions.json$/
      begin
        input = load filename
        columns = input['columns']
        data = input['data']
        key = columns[0]
        if filename =~ /\/(\w*)\.json/
          name = $1
          @tables[name] = index key, input
          @columns[name] = input['columns']
          puts "#{$1.ljust 25}:#{key.ljust 15}#{data.length} rows x #{columns.length} columns"
        end
      rescue Exception => e
        puts "trouble:"
        puts e.message
        @trouble += 1
      end
    end

    load("try6/Tier3Functions.json")['data'].each do |row|
      @formulas[row['Function Name']] = row['Function']
    end

    puts "#{@trouble} trouble"
  end

  def load filename
    text = File.read(filename)
    input = JSON.parse(text)
  end

  def index key, table
    hash = {}
    table['data'].each do |row|
      hash[row[key]] = row
    end
    return hash
  end

  def fetch from, column
    (table, key) = from
    puts "-- [#{table},#{key}] #{column}}"
    throw Exception.new("No table named '#{table}'") unless tab = @tables[table]
    throw Exception.new("No row with key '#{key}' in #{table}") unless row = tab[key]
    throw Exception.new("No column with name '#{column}' in #{table}") unless val = row[column]
    if formula = row["#{column}_Formula"]
      puts "   #{formula}"
      got = execute from, formula
      judge = got == val ? "GOOD" : "BAD"
      puts "#{judge}: had #{val}, got #{got}"
    end
    val
  end
  
  def execute from, formula
    expr = @parser.parse_excel formula
    eval from, expr
  end
  
  def eval from, expr
    return nil unless expr
    puts "---- #{expr.inspect}"
    case
    when s=expr[:sheet]
      # label = expr[:absrow] && expr[:abscol] ? "[label=\"$\"]" : ""
      # # label = "[label=\"#{[:abscol, :absrow].collect {|abs| expr[abs] ? "$" : "."}}\"]"
      # @dot << "#{quote s} [fillcolor=white];" unless @columns[@sheets[s.to_s]]
      # @dot << "#{quote from} -> #{quote s} #{label};"
      throw Exception.new "Can't fetch from sheet: '#{s}'"
    when r=expr[:absrow]||expr[:row]
      c=expr[:abscol]||expr[:col]
      throw Exception.new "Can't fetch row: '#{r}', column: '#{c}'"
    when o=expr[:op]
      left = eval from, expr[:left]
      right = eval from, expr[:right]
      case o
      when '+': left + right
      when '-': left - right
      when '*': left * right
      when '/': left / right
      when '=': left == right
      when '<>': left != right
      when '>': left > right
      when '<': left < right
      when '>=': left >= right
      when '<=': left <= right
      else throw Exception.new "Don't know op: '#{o}'"
      end
    when f=expr[:function]
      # @dot << "#{quote from} -> #{quote f};"
      args = [expr[:args]].flatten
      case f
      when 'SUM': sum args.collect{|arg|eval(from,arg)}
      when 'VLOOKUP': vlookup eval(from,args[0]), args[1], args[2], eval(from,args[3])
      when 'IF': eval(from,args[0]) ? eval(from,args[1]) : eval(from,args[2])
      else throw Exception.new "Don't know function: '#{f}'"
      end
    when c=expr[:column]
      # label = expr[:current] ? "[label=\"@\"]" : ""
      # @dot << "#{quote c} [fillcolor=lightgray];" unless @columns[c.to_s]
      # @dot << "#{quote from} -> #{quote c} #{label};" unless c=='Material'
      # @dot << "#{quote expr[:table]} [shape=box]; #{quote c} -> #{quote expr[:table]};" if expr[:table]
      
      # throw Exception.new "Can't find table: '#{expr[:table]}'" unless table = @tables[expr[:table].to_s]
      if e=expr[:ending]
        cols = @columns[from[0]]
        indx = cols.index(c.to_s) .. cols.index(e[:column].to_s)
        range = cols[indx].collect{ |col| fetch [expr[:table].to_s, from[1]], col }
      else
        fetch from, c.to_s
      end
    when f=expr[:formula]
      throw Exception.new "Don't know formula: '#{f}'" unless fmla = @formulas[f.to_s]
      eval from, fmla
    when s=expr[:string]:
      return s.to_s
    when n=expr[:number]
      return n.to_f
    when b=expr[:boolean]
      return b.to_s[0]==?T ? true : false
    else
      puts "Can't Eval:"
      puts JSON.pretty_generate(expr)
    end
  end

  def sum vector
    puts "sum: #{vector.inspect}"
    vector.flatten.inject(0){|sum,each| sum + each}
  end

  def vlookup key, table, column, exact
    t=table[:formula]
    throw Exception.new "Can't find table '#{t}'" unless tab = @tables[t.to_s]
    throw Exception.new "Can't find row for '#{key}' in table #{t}" unless row = tab[key.to_s]
    c = column[:formula]
    f = @formulas[c.to_s]
    r = @parser.parse_excel f
    n = (r[:abscol].to_s[0].to_i)-('A'[0].to_i)+1
    col = @columns[t.to_s][n]
    throw Exception.new "Can't find column '#{col}' in table #{t}" unless val = row[col]
    val
  end

end

@calc = Calculate.new
def test expr
  puts expr
  puts @calc.execute [], "=#{expr}"
end

test "(1/3)*3"
test "SUM(10,20,30)"
test 'IF(5>10,"good",20.665)'

puts @calc.fetch ['Tier1MSISummary','Cotton fabric'], ' Chemistry Total'

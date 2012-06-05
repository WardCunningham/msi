require 'rubygems'
require 'json'

@table = {}
@material = {}

def load filename
  JSON.parse(File.read(filename))
end

def index key, table
  hash = {}
  table['data'].each do |row|
    hash[row[key]] = row
  end
  return hash
end

Dir.glob('try9/*.json') do |filename|
  (prefix, table, sufix) = filename.split /[\/\.]/
  @table[table] = input = load(filename)
  @material[table] = index input['columns'].first, input if (40..50).include? input['data'].length
  puts "#{table.ljust 30} #{input['data'].length} rows x #{input['columns'].length} columns (#{input['columns'].first})"
end

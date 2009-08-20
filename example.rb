require 'data_map'

countries = YAML.load_file('lang/en/countries.yml')
data = {}
countries.keys.each { |code| data[code] = rand(10000000) if rand(4) > 0 }

m = DataMap::WorldMap.new

m.data = data

m.title = 'Example data'

m.identify_countries
m.make_ranges_log
m.make_colors
m.map_values
m.make_legend
m.save_file '/tmp/map.png', :size => '1024x768', :quality => 80

puts "Output at /tmp/map.png"

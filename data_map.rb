require 'color'
require 'yaml'
require 'RMagick'
module DataMap

  # Plots a world map as a file.
  # The format can be SVG or any other supported by RMagick.
  class WorldMap

    # Map constructor. Just creates a WorldMap object that can be manipulated later.
    # Options:
    #   template: What SVG file will be used as the map template to be colored. 
    #             The file's content will be stored in the attribute @svg.
    #             Default: WorldMap.default_template
    #
    #   lang: Language used to show the country names. The files lang/<language>/{strings,countries}.yml must exist. 
    #         See the 'en' example. 
    #         The value will be stored in the attribute @lang.
    #         Default: WorldMap.default_language
    #
    #   palette: Color palette to be used. The color palette file must one color per line. 
    #            A color line must be represented as the R, G and B values separated by a single space.
    #            See the default color palette for an example.
    #            The value will be stored in the attribute @palette.
    #            Default: WorldMap.default_palette
    #
    #   data: The actual information you want to represent in the map.
    #         Must be a hash in the format <country code> => <value>.
    #         The value will be stored in the attribute @data.
    #         Example: { "en" => 100, "br" => 50, "es" => 30 }
    #         Default: {}
    #
    #   js: An array of Javascript files paths to be included in the generated SVG.
    #       To get them really included, the method add_js must be called.
    #       The value will be stored in the attribute @js.
    #       Default: []
    #
    # So, the above values passed will be stored as attributes of the map object.
    def initialize(options = {})
      
      template   = options[:template] || WorldMap.default_template
      @lang      = options[:lang]     || WorldMap.default_language
      @palette   = options[:palette]  || WorldMap.default_palette
      @data      = options[:data]     || {}
      @js        = options[:js]       || []
      @svg       = File.read(template)

    end

    # Includes in SVG all javascript paths that are stored in the @js attribute.
    # Actually creates a script element in the SVG for each @js element.
    def add_js
      @js.each do |file|
        @svg.gsub!('<!-- javascript -->','<!-- javascript --><script xlink:href="' + file + '" type="text/ecmascript" />')
      end
    end

    # For each country in the SVG, adds two text attributes and javascript functions passing the actual SVG element as parameter.
    # These functions must be defined later in your application.
    # Added attributes:
    #   country-name: The country name in lang/<@lang>/countries.yml
    #   country-value: The value for this country as stored in @data
    #   onmouseover: worldMapOver(this) (you must define this function later in your application)
    #   onmouseout: worldMapOut(this) (you must define this function later in your application)
    #   onclick: worldMapClick(this) (you must define this function later in your application)
    #   ondblclick: worldMapDblClick(this) (you must define this function later in your application)
    def identify_countries
      names = YAML.load_file( File.dirname(File.expand_path(__FILE__)) + '/lang/' + @lang + '/countries.yml' )
      names.each do |code,name|
        @svg.gsub!("class=\"land #{code}\"", "class=\"land #{code}\" country-name=\"#{name}\" country-value=\"#{@data[code]}\" onmouseover=\"worldMapOver(this)\" onmouseout=\"worldMapOut(this)\" onclick=\"worldMapClick(this)\" ondblclick=\"worldMapDblClick(this)\"")
      end
    end

    # Adds a legend to the map, using the strings and country names defined in lang/<@lang>/{countries,strings}.yml.
    # Use the ranges and respective colors defined in @ranges.
    def make_legend
      strings = YAML.load_file( File.dirname(File.expand_path(__FILE__)) + '/lang/' + @lang + '/strings.yml' )
      i = 0
      legend = ''
      @ranges.each do |r|
        y = 75 + 40 * i
        legend += '<rect x="2750" class="legend" y="' + y.to_s + '" width="27" height="27" fill="' + r[:color] + '" />
                   <text class="label" x="2800" y="' + (y + 23).to_s + '" style="font-size:28px; font-family:sans-serif"><tspan>' + 
                   [ strings['between'], r[:range][0].to_s, strings['and'], r[:range][1] ].join(' ') +
                   '</tspan></text>'
        i += 1
      end
      y = 75 + 40*i
      legend += '<rect x="2750" class="legend" y="' + y.to_s + '" width="27" height="27" style="fill:#b9b9b9" />
                 <text class="label" x="2800" y="' + (y + 23).to_s + '" style="font-size:28px; font-family:sans-serif"><tspan>' + strings['no_data'] + '</tspan></text>'
      @svg.gsub!("</g></g></svg>", legend + "</g></g></svg>")
    end

    # Paint each country with the range's color that the country value fits.
    # Raises an exception if the value doesn't fit in any range.
    def map_values
      @data.each do |code,value|
        fit = false
        @ranges.each do |r|
          if value.between?(r[:range][0],r[:range][1])
            self.paint_country(code,r[:color])
            fit = true
            break
          end
        end
        raise "Unexpected error! Value #{value} doesn't fit in any range!" unless fit
      end
    end

    # For each range present in @ranges, define a color for it.
    # The colors are those in the @palette file.
    # Raises an exception if there are more ranges than colors.
    def make_colors
      palette = File.open(@palette).readlines
      raise "There are more ranges (#{@ranges.size}) than colors (#{palette.size})!" if @ranges.size > palette.size
      @ranges.each_index do |i|
        r,g,b = palette[i].split.collect{ |s| s.to_i }
        @ranges[i][:color] = Color::RGB.new(r,g,b).html
      end
    end

    # Make the value ranges using a linear function.
    def make_ranges_linear
      min, max = @data.values.sort.first, @data.values.sort.last
      value = ( ( max - min ) / File.open(@palette).readlines.size ).to_i + 1
      offset = (( value / 10 ** (value.to_s.size - 1) ).round + 1)* 10 ** (value.to_s.size - 1)
      last = offset > min ? offset : min
      @ranges = [ { :range => [1, last-1] } ]
      while last < max do
        @ranges << { :range => [last, last + offset - 1] }
        last += offset
      end
      @ranges << { :range => [last, last + offset] }
    end

    # Make the value ranges using a log function.
    # You can set the log base if desired. If not set by you, the default value is 10.
    # For most of the maps, it's better to use the log function than the linear one.
    def make_ranges_log(base = 10)
      min, max = @data.values.sort.first, @data.values.sort.last
      last = base ** min.to_s.size
      @ranges = [ { :range => [last / base, last-1] } ]
      while last < max do
        @ranges << { :range => [last, last * base - 1] }
        last = last * base
      end
      @ranges << { :range => [last, last * 10] }
    end

    # Just paint a country with some color.
    # Parameters:
    #   code: Country code
    #   color: Some color string such as '#FFCC33' or 'black'
    def paint_country(code,color)
      @svg.gsub!(Regexp.new("fill=\"[^\"]+\" class=\"land #{code}\""), "fill=\"#{color}\" class=\"land #{code}\"")
    end

    # Outputs the map to a file in some format.
    # Parameters:
    #   output: The output filename
    #   options: A hash of options:
    #     size: A size string as recognized by RMagick. Default: The template size
    #     quality: An integer from 0 to 100. Default: 100
    def save_file(output = 'output.svg', options = {})
      format = File.extname(output).gsub!(/\./,'')
      if format == 'svg'
        svg = File.open(output, 'w')
        svg << @svg
        svg.close
      else
        image = Magick::Image::from_blob(@svg)[0]
        image.change_geometry!(options[:size]) { |cols, rows, img| img.resize!(cols, rows) } unless options[:size].nil?
        image.write(output) {
          self.format = format
          self.quality = options[:quality] || 100
        }
      end
    end

    # Default methods

    # Sequence of steps normally necessary to make a full map.
    # Just call some methods. See the source code below to understand.
    def default_behaviour
      self.add_js
      self.identify_countries
      self.make_ranges_log
      self.make_colors
      self.map_values
      self.make_legend
      self.save_file
    end
  
    # Default template to use when none is set
    def self.default_template
      File.dirname(File.expand_path(__FILE__)) + '/templates/default_world_map.svg'
    end

    # Default palette to use when none is set
    def self.default_palette
      File.dirname(File.expand_path(__FILE__)) + '/palettes/tango.color'
    end

    # Default language to use when none is set
    def self.default_language
      'en'
    end
    
    # Get a country name from the country code, using the file lang/<@lang>/countries.yml
    def self.country_name(code, lang = default_language)
      YAML.load_file( File.dirname(File.expand_path(__FILE__)) + '/lang/' + lang + '/countries.yml' )[code]
    end

    # Some get's and set's methods

    # Alter @data information
    def alter_data(data = {})
      @data = @data.merge(data)
    end

    # Sets @data information
    # It must be a hash whose key is the country code in ISO 3166-1 format and the value is a number
    def data=(data)
      @data = data
    end

    # Gets @data
    def data
      @data
    end

    # Gets @lang
    def lang
      @lang
    end

    # Sets @lang. Must be a string, and the files lang/<@lang>/{countries,strings}.yml must be present
    def lang=(lang)
      @lang = lang
    end

    # Gets @palette
    def palette
      @palette
    end

    # Sets @palette. Must be a path for a file.
    # Each line of this file must be a color, with its red, green and blue values separated by spaces.
    # See WorldMap.default_palette as example.
    def palette=(palette)
      @palette = palette
    end

    # Gets the content of the @svg file
    def svg
      @svg
    end

    # Sets the content of the @svg file
    def svg=(svg)
      @svg = svg
    end

    # Get @ranges
    def ranges
      @ranges
    end

    # Sets @ranges.
    # You can set it manually using this method or using the methods make_ranges_linear or make_ranges_log and then make_colors.
    # The format must be an array of hashes, as each hash is like { :range => [<from>,<to>], :color => <some color string> }
    # When a country value fits in any range, this country will be painted in the color defined.
    def ranges=(ranges)
      @ranges = ranges
    end

    # Gets @js
    def js
      @js
    end

    # Sets @js. Must be an array of Javascript file paths.
    def js=(js)
      @js = js
    end

    # Gets @title
    def title
      @title
    end

    # Sets @title. The title is just a string.
    def title=(title)
      @svg.gsub!(/<g id="map-and-legend"[^>]*>/,'<g id="map-and-legend">')
      @svg.gsub!(/<text id="map-title" x="10" y="25" font-size="60" font-family="sans-serif">[^<]*<\/text>/,'')
      @svg.gsub!('<g id="map-and-legend">','<g id="map-and-legend" transform="translate(0,50)"><text id="map-title" x="10" y="25" font-size="60" font-family="sans-serif">' + title + '</text>') if title
      @title = title
    end

  end

end

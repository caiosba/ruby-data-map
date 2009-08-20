require 'test/unit'
require 'tempfile'
require File.dirname(__FILE__) + '/../data_map'

# Test the DataMap library
class WorldMapTest < Test::Unit::TestCase

  def test_assert
    assert true
  end

  def test_initialize_default
    m = DataMap::WorldMap.new
    assert_equal File.open(DataMap::WorldMap.default_template).read, m.svg
    assert_equal DataMap::WorldMap.default_language, m.lang
    assert_equal DataMap::WorldMap.default_palette, m.palette
    assert_equal([], m.js)
    assert_equal({}, m.data)
  end

  def test_initialize_custom
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :lang => 'pt-BR', :palette => '/tmp/test.color', :data => { :br => 10 }
    assert_equal File.open(svg.path).read, m.svg
    assert_equal 'pt-BR', m.lang
    assert_equal '/tmp/test.color', m.palette
    assert_equal({ :br => 10 }, m.data)
  end

  def test_identify_countries
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path class="land br" d="125,45" /><path class="land es" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50 }
    m.identify_countries
    assert_equal '<svg><g><path class="land br" country-name="brazil" country-value="100" onmouseover="worldMapOver(this)" onmouseout="worldMapOut(this)" onclick="worldMapClick(this)" ondblclick="worldMapDblClick(this)" d="125,45" /><path class="land es" country-name="spain" country-value="50" onmouseover="worldMapOver(this)" onmouseout="worldMapOut(this)" onclick="worldMapClick(this)" ondblclick="worldMapDblClick(this)" /></g></svg>', m.svg
  end

  def test_make_legend
    svg = Tempfile.new rand(100)
    svg << '<svg><g><g><path class="land br" d="125,45" /></g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.ranges = [ { :range => [0,199], :color => '#fc3' }, { :range => [200,400], :color => '#ccc' } ]
    m.make_legend
    assert_equal '<svg><g><g><path class="land br" d="125,45" /><rect x="2750" class="legend" y="75" width="27" height="27" fill="#fc3" /><text class="label" x="2800" y="98" style="font-size:28px; font-family:sans-serif"><tspan>Between 0 and 199</tspan></text><rect x="2750" class="legend" y="115" width="27" height="27" fill="#ccc" /><text class="label" x="2800" y="138" style="font-size:28px; font-family:sans-serif"><tspan>Between 200 and 400</tspan></text><rect x="2750" class="legend" y="155" width="27" height="27" style="fill:#b9b9b9" /><text class="label" x="2800" y="178" style="font-size:28px; font-family:sans-serif"><tspan>No information available</tspan></text></g></g></svg>', m.svg.gsub!(/\n\s*/,'')
  end

  def test_map_values
    svg = Tempfile.new rand(100)
    svg << '<svg><g><g><path fill="#ccc" class="land br" /><path fill="#ccc" class="land es" /></g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50 }
    m.ranges = [ { :range => [0,99], :color => '#c00' }, { :range => [100,200], :color => '#fc3' } ]
    m.map_values
    assert_equal '<svg><g><g><path fill="#fc3" class="land br" /><path fill="#c00" class="land es" /></g></g></svg>', m.svg
  end

  def test_map_values_error
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 50 }
    m.ranges = [ { :range => [100,200] } ]
    assert_raise RuntimeError do
      m.map_values
    end
  end

  def test_make_colors
    svg = Tempfile.new rand(100)
    svg << '<svg><g><g><path fill="#ccc" class="land br" /><path fill="#ccc" class="land es" /></g></g></svg>'
    svg.close
    colors = Tempfile.new rand(100)
    colors << "255 0 0\n0 255 0"
    colors.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50 }, :palette => colors.path
    m.ranges = [ { :range => [0,99] }, { :range => [100,200] } ]
    m.make_colors
    assert_equal([ { :range => [0,99], :color => '#ff0000' }, { :range => [100,200], :color => '#00ff00' } ], m.ranges)
  end

  def test_make_colors_error
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></svg>'
    svg.close
    colors = Tempfile.new rand(100)
    colors << "255 0 0"
    colors.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :palette => colors.path
    m.ranges = [ { :range => [0,99] }, { :range => [100,200] } ]
    assert_raise RuntimeError do
      m.make_colors
    end
  end

  def test_make_ranges_linear
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></svg>'
    svg.close
    colors = Tempfile.new rand(100)
    colors << "255 0 0\n0 255 0\n0 0 255\n0 0 0"
    colors.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50, "pt" => 20 }, :palette => colors.path
    m.make_ranges_linear
    assert_equal([{:range => [1,29]}, {:range => [30,59]}, {:range => [60,89]}, {:range => [90,119]}, {:range => [120,150]}], m.ranges)
  end

  def test_make_ranges_log
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50, "pt" => 20, "fr" => 5 }
    m.make_ranges_log
    assert_equal([{:range => [1,9]}, {:range => [10,99]}, {:range => [100,1000]}], m.ranges)
  end

  def test_paint_country
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.paint_country('br','#fc0')
    assert_equal '<svg><g><path id="test" fill="#fc0" class="land br" stroke="1" /></g></svg>', m.svg
  end

  def test_save_file
    out = Tempfile.new rand(100)
    out << 'test'
    out.close
    m = DataMap::WorldMap.new :data => { "br" => 100 }
    m.save_file
    assert File.exists? 'output.svg'
    assert_equal m.svg, File.open('output.svg').read
    FileUtils.rm('output.svg')
    m.save_file(out.path + '.png')
    assert_equal "image/png\n", %x[file -bi #{out.path}.png]
  end

  def test_must_have_default_settings
    assert_kind_of String, DataMap::WorldMap.default_template
    assert_kind_of String, DataMap::WorldMap.default_language
    assert_kind_of String, DataMap::WorldMap.default_palette
  end

  def test_alter_data
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50 }
    m.alter_data "fr" => 20, "br" => 30
    assert_equal({ "br" => 30, "fr" => 20, "es" => 50 }, m.data)
  end

  def test_set_data
    svg = Tempfile.new rand(100)
    svg << '<svg><g></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.data = { "es" => 50 }
    assert_equal({ "es" => 50 }, m.data)
  end

  def test_get_data
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100, "es" => 50 }
    assert_equal({ "br" => 100, "es" => 50 }, m.data)
  end

  def test_get_lang
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :lang => 'es'
    assert_equal 'es', m.lang
  end

  def test_set_lang
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :lang => 'es'
    m.lang = 'fr'
    assert_equal 'fr', m.lang
  end

  def test_get_palette
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :palette => 'test'
    assert_equal 'test', m.palette
  end

  def test_set_palette
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :palette => 'test'
    m.palette = 'changed'
    assert_equal 'changed', m.palette
  end

  def test_get_svg
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    assert_equal '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>', m.svg
  end

  def test_set_svg
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.svg = '<svg>changed</svg>'
    assert_equal '<svg>changed</svg>', m.svg
  end

  def test_get_and_set_ranges
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    assert_nil m.ranges
    m.ranges = [ { :range => [1,200] } ]
    assert_equal([ { :range => [1,200] } ], m.ranges)
  end

  def test_get_js
    svg = Tempfile.new rand(100)
    svg << '<svg><g><!-- javascript --></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }, :js => ['dom.js','effects.js']
    m.add_js
    assert_equal '<svg><g><!-- javascript --><script xlink:href="effects.js" type="text/ecmascript" /><script xlink:href="dom.js" type="text/ecmascript" /></g></svg>', m.svg
  end

  def test_no_js
    svg = Tempfile.new rand(100)
    svg << '<svg><g><!-- javascript --></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    assert_equal '<svg><g><!-- javascript --></g></svg>', m.svg
  end

  def test_set_js
    svg = Tempfile.new rand(100)
    svg << '<svg><g><!-- javascript --></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.js = ['file']
    assert_equal(['file'], m.js)
  end

  def test_add_js
    svg = Tempfile.new rand(100)
    svg << '<svg><g><!-- javascript --></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    m.js = ['file']
    m.add_js
    assert_equal '<svg><g><!-- javascript --><script xlink:href="file" type="text/ecmascript" /></g></svg>', m.svg
  end

  def test_get_title
    svg = Tempfile.new rand(100)
    svg << '<svg><g><path id="test" fill="#ccc" class="land br" stroke="1" /></g></svg>'
    svg.close
    m = DataMap::WorldMap.new :template => svg.path, :data => { "br" => 100 }
    assert_nil m.title
    m.title = 'Test'
    assert_equal 'Test', m.title
  end

  def test_country_name
    assert_equal 'brazil', DataMap::WorldMap.country_name('br')
  end

end

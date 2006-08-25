require 'webgen/test'

class HorizontalMenuStyleTest < Webgen::PluginTestCase

  plugin_files [
                'webgen/plugins/menustyles/horizontal.rb',
                'webgen/plugins/filehandlers/directory.rb',
                'webgen/plugins/filehandlers/page.rb'
               ]

  plugin_to_test 'MenuStyles::HorizontalMenuStyle'

  def test_submenu
    root = @manager['FileHandlers::FileHandler'].instance_eval { build_tree }
    flunk
  end

end
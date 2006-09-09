require 'webgen/test'

class FileCopyHandlerTest < Webgen::PluginTestCase

  plugin_files [
    'webgen/plugins/filehandlers/directory.rb',
    'webgen/plugins/filehandlers/copy.rb'
  ]
  plugin_to_test 'File/CopyHandler'

  def test_create_node
    root = @manager['Core/FileHandler'].instance_eval { build_tree }
    src_file = File.join( param_for_plugin( 'Core/Configuration', 'srcDir' ), 'file1.page' )
    file = @plugin.create_node( src_file, root, {'test'=>'hallo', 'title'=>'none'} )
    assert_equal( 'file1.page', file.path )
    assert_equal( 'file1.page', file['title'] )
    assert_equal( 'hallo', file['test'] )
    assert_equal( src_file, file.node_info[:src] )
    assert_equal( @plugin, file.node_info[:processor] )

    assert_same( file, @plugin.create_node( src_file, root, {} ) )
  end

  def test_write_node
    root = @manager['Core/FileHandler'].instance_eval { build_tree }
    src_file = File.join( param_for_plugin( 'Core/Configuration', 'srcDir' ), 'file1.page' )
    file = @plugin.create_node( src_file, root, {} )

    file.write_node
    assert( File.exists?( file.full_path ) )
    assert( !@manager['Core/FileHandler'].file_modified?( file.node_info[:src], file.full_path ) )
    FileUtils.touch( file.node_info[:src] )
    file.write_node
    assert( !@manager['Core/FileHandler'].file_modified?( file.node_info[:src], file.full_path ) )
  ensure
    FileUtils.rm_r( root.full_path, :force => true )
  end

end


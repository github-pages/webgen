require 'fileutils'
require 'ups/ups'
require 'thgexception'
require 'node'
require 'plugins/fileHandler/fileHandler'

class FileCopyPlugin < UPS::Plugin

    NAME = "Copy Files"
    SHORT_DESC = "Copies files from source to destination without modification"
    DESCRIPTION = <<-EOF.gsub( /^\s*/, '' ).gsub( /\n/, ' ' )
		Implements a generic file copy plugin. All the file types which are specified in the
		configuration file are copied without any transformation into the destination directory.
    EOF


	def init
		#TODO types = Configuration.instance.pluginData['fileCopy'].text
        types = "css,jpg,png,gif,page"
		unless types.nil?
			types.split( ',' ).each do |type|
				UPS::Registry['File Handler'].extensions[type] ||= self
			end
		end
	end


	def create_node( srcName, parent )
		relName = File.basename srcName
		node = Node.new parent
        node['dest'] = node['src'] = node['title'] = relName
        node
	end


	def write_node( node, filename )
        srcFile = node.recursive_value 'src'
        if FileTest.exists?( filename ) && ( File.mtime( filename ) == File.mtime( srcFile ) )
            #TODO use log4r
            print "file #{srcFile} not copied, destination file is up to date\n"
            return
        end
		FileUtils.cp( srcFile, filename )
        File.utime( File.atime( srcFile ), File.mtime( srcFile ), filename )
	end

end

UPS::Registry.register_plugin FileCopyPlugin

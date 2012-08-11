# -*- encoding: utf-8 -*-

require 'rbconfig'

module Webgen

  # This class is used for loading extension bundles. It provides a DSL for the most commonly needed
  # commands.
  #
  # When an extension bundle is provided by a Rubygem and the Rubygem is not already activated, the
  # Rubygem is automatically activated. This only works when one follows the standard naming
  # conventions for webgen extension bundles.
  class BundleLoader

    # Create a new BundleLoader object belonging to the website object +website+.
    def initialize(website, ext_dir)
      @website = website
      @website.ext.bundles = {}
      @ext_dir = ext_dir
      @loaded = []
      @stack = []
    end

    # Load the extension bundle in the context of this BundleLoader object.
    def load(name)
      file = resolve_init_file(name)
      raise(ArgumentError, "Extension bundle '#{name}' not found") if !file
      file = File.expand_path(file)
      return if @loaded.include?(file)

      @loaded.push(file)
      @stack.push(file)
      self.instance_eval(File.read(file), file)
      @stack.pop

      if file != File.expand_path(File.join(@ext_dir, 'init.rb'))
        name = File.basename(File.dirname(file))
        info_file = File.join(File.dirname(file), 'info.yaml')
        @website.ext.bundles[name] = (File.file?(info_file) ? info_file : nil)
      end
    end

    # Search in the website extension directory and then in the load path to find the initialization
    # file of the bundle.
    def resolve_init_file(name)
      name.sub!(/(\/|^)init\.rb$/, '')

      if name =~ /\A[\w-]+\z/
        begin
          Gem::Specification.find_by_name("webgen-#{name}-bundle").activate
        rescue Gem::LoadError
        end
      end

      possible_init_file_names(name).each {|path| return path if File.file?(path)}

      nil
    end
    private :resolve_init_file

    # Create all possible initialization file names for the given directory name.
    def possible_init_file_names(dir_name)
      [File.join(@ext_dir, dir_name, 'init.rb')] +
        $LOAD_PATH.map {|path| File.join(path, 'webgen/bundle', dir_name, 'init.rb')}
    end
    private :possible_init_file_names

    # :section: DSL methods
    #
    # All following method are DSL methods that are just provided for convenience.

    # Require the file relative to the currently loaded file.
    def require_relative(file)
      require(File.join(File.dirname(@stack.last), file))
    end

    # Define a configuration option. See Webgen::Configuration#define_option for more information.
    def option(name, default, description, &validator)
      @website.config.define_option(name, default, description, &validator)
    end
    private :option

    # Return the website object.
    def website
      @website
    end
    private :website

    # Mount the directory relative to the currently loaded file on the given mount point as passive
    # source.
    def mount_passive(dir, mount_point = '/')
      @website.config['sources.passive'] = [[mount_point, :file_system, absolute_path(dir)]] +
        @website.config['sources.passive']
    end
    private :mount_passive

    # Return the absolute path of the given path which is assumed to be relative to the currently
    # loaded file.
    def absolute_path(path)
      File.expand_path(File.join(File.dirname(@stack.last), path))
    end
    private :absolute_path

  end

end
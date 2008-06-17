require 'yaml'
require 'webgen/sourcehandler/base'
require 'webgen/websiteaccess'

module Webgen::SourceHandler

  class Metainfo

    include Base
    include Webgen::WebsiteAccess

    CKEY = [:metainfo, :nodes]

    def initialize
      website.blackboard.add_listener(:node_changed?, method(:node_changed?))
      website.blackboard.add_listener(:before_node_created, method(:before_node_created))
      website.blackboard.add_listener(:before_node_deleted, method(:before_node_deleted))
      website.blackboard.add_listener(:after_node_created, method(:after_node_created))
      self.nodes ||= Set.new
    end

    def create_node(parent, path)
      page = page_from_path(path)
      super(parent, path) do |node|
        [[:mi_paths, 'paths'], [:mi_alcn, 'alcn']].each do |mi_key, block_name|
          node.node_info[mi_key] = {}
          YAML::load(page.blocks[block_name].content).each do |key, value|
            key = File.expand_path(key =~ /^\// ? key : File.join(parent.absolute_lcn, key))
            node.node_info[mi_key][key.chomp('/')] = value
          end if page.blocks.has_key?(block_name)
        end

        mark_all_matched_dirty(node)

        self.nodes << node
        self.nodes = self.nodes.sort_by {|n| n.absolute_lcn}
      end
    end

    def nodes; website.cache.permanent[CKEY]; end
    def nodes=(val); website.cache.permanent[CKEY] = val; end

    #######
    private
    #######

    def mark_all_matched_dirty(node)
      source_paths = website.blackboard.invoke(:source_paths)
      node.tree.node_access[:alcn].each do |path, n|
        n.dirty = true if node.node_info[:mi_paths].any? {|pattern, mi| source_paths[n.node_info[:src]] =~ pattern }
        n.dirty = true if node.node_info[:mi_alcn].any? {|pattern, mi| n =~ pattern }
      end
    end

    def before_node_created(parent, path)
      self.nodes.each do |node|
        node.node_info[:mi_paths].each do |pattern, mi|
          path.meta_info.update(mi) if path =~ pattern
        end
      end
    end

    def after_node_created(node)
      self.nodes.each do |n|
        n.node_info[:mi_alcn].each do |pattern, mi|
          node.meta_info.update(mi) if node =~ pattern
        end
      end
    end

    def node_changed?(node)
      return if self.nodes.include?(node)
      path = website.blackboard.invoke(:source_paths)[node.node_info[:src]]
      self.nodes.each do |n|
        if n.changed? &&
            (n.node_info[:mi_paths].any? {|pattern, mi| path =~ pattern} ||
             n.node_info[:mi_alcn].any? {|pattern, mi| node =~ pattern})
          node.dirty = true
          return
        end
      end
    end

    def before_node_deleted(node)
      return unless node.node_info[:processor] == self.class.name
      mark_all_matched_dirty(node)
      self.nodes.delete(node)
    end

  end

end

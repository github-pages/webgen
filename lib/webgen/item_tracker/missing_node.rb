# -*- encoding: utf-8 -*-

require 'set'
require 'webgen/item_tracker'

module Webgen
  class ItemTracker

    # This class is used to track unresolved absolute node paths.
    #
    # The item for this tracker is the unresolved absolute node path and, optionally, a language.
    #
    # For example:
    #
    #   website.ext.item_tracker.add(some_node, :missing_node, '/dir/missing.html')
    #   website.ext.item_tracker.add(some_node, :missing_node, '/dir/missing.html', 'de')
    #
    class MissingNode

      def initialize(website) #:nodoc:
        @website = website
        @at_least_one_node_created = true
        @stop_reporting = false
        @nodes_to_ignore = Set.new

        @website.blackboard.add_listener(:reused_existing_node, 'item_tracker.missing_node') do |node, path|
          @nodes_to_ignore << node
        end
        @website.blackboard.add_listener(:after_node_created, 'item_tracker.missing_node') do |node|
          @at_least_one_node_created = true unless @nodes_to_ignore.include?(node)
        end
        @website.blackboard.add_listener(:after_all_nodes_written, 'item_tracker.missing_node') do
          if @at_least_one_node_created
            @at_least_one_node_created = false
          else
            @stop_reporting = true
          end
          @nodes_to_ignore = Set.new
        end
        @website.blackboard.add_listener(:website_generated, 'item_tracker.missing_node') do
          @at_least_one_node_created = true
          @stop_reporting = false
          @nodes_to_ignore = Set.new
        end
      end

      def item_id(path, lang = nil) #:nodoc:
        [path, lang]
      end

      def item_data(path, lang) #:nodoc:
        @website.tree.resolve_node(path, lang).nil?
      end

      def item_changed?(iid, old_data) #:nodoc:
        return false if @stop_reporting
        missing = item_data(*iid)
        missing || missing != old_data
      end

      def referenced_nodes(iid, missing) #:nodoc:
        [iid.first]
      end

      def item_description(iid, data) #:nodoc:
        path, lang = iid
        "Missing acn, alcn or dest path <#{path}>" << (lang.nil? ? '' : " in language '#{lang}'")
      end

    end

  end
end

require 'commonmarker'

module ComposableAgents
  module Utils
    # Internal util methods to handle Markdown
    module Markdown
      class << self
        # Align markdown headers in a String to a given level.
        # This method parses the String as a markdown document, sees the minimum current header level,
        # and changes it while preserving the structure and hierarchy so that this min level is equal to `level`.
        #
        # Parameters::
        # * *markdown* (String): The markdown content to align
        # * *level* (Integer): The target level for the minimum header [default: 2]
        # Result::
        # * String: The aligned markdown content
        def align_markdown_headers(markdown, level: 2)
          doc = Commonmarker.parse(markdown)
          min_level = find_minimum_header_level(doc)
          return markdown if min_level.nil? || min_level == level

          adjust_header_levels(doc, level - min_level)
          doc.to_commonmark
        end

        # Find the minimum header level in a CommonMarker document
        #
        # Parameters::
        # * *doc* (CommonMarker::Document): The parsed CommonMarker document
        # Result::
        # * Integer or nil: The minimum header level found, or nil if no headers exist
        def find_minimum_header_level(doc)
          min_level = nil
          doc.walk do |node|
            if node.type == :heading
              current_level = node.header_level
              min_level = current_level if min_level.nil? || current_level < min_level
            end
          end
          min_level
        end

        # Adjust header levels in a CommonMarker document by a given difference
        #
        # Parameters::
        # * *doc* (CommonMarker::Document): The parsed CommonMarker document
        # * *level_diff* (Integer): The difference to add to each header level
        def adjust_header_levels(doc, level_diff)
          doc.walk do |node|
            node.header_level = node.header_level + level_diff if node.type == :heading
          end
        end
      end
    end
  end
end

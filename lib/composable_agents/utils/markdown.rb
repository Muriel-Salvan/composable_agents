require 'commonmarker'

module ComposableAgents
  # Various internal helpers and utilities
  module Utils
    # Internal util methods to handle Markdown
    module Markdown
      class << self
        # Align markdown headers in a String to a given level.
        # This method parses the String as a markdown document, sees the minimum current header level,
        # and changes it while preserving the structure and hierarchy so that this min level is equal to `level`.
        #
        # @param markdown [String] The markdown content to align
        # @param level [Integer] The target level for the minimum header
        # @return [String] The aligned markdown content
        def align_markdown_headers(markdown, level: 2)
          doc = Commonmarker.parse(markdown)
          min_level = find_minimum_header_level(doc)
          return markdown if min_level.nil? || min_level == level

          adjust_header_levels(doc, level - min_level)
          # Unescape dots in headers
          # TODO: Remove this gsub when CommonMarker will be fixed.
          doc.to_commonmark.gsub(/^\#{1,6}\s+\h+\K\\\. /, '. ')
        end

        # Find the minimum header level in a CommonMarker document
        #
        # @param doc [CommonMarker::Document] The parsed CommonMarker document
        # @return [Integer, nil] The minimum header level found, or nil if no headers exist
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
        # @param doc [CommonMarker::Document] The parsed CommonMarker document
        # @param level_diff [Integer] The difference to add to each header level
        def adjust_header_levels(doc, level_diff)
          doc.walk do |node|
            node.header_level = node.header_level + level_diff if node.type == :heading
          end
        end
      end
    end
  end
end

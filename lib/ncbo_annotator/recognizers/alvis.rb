module Annotator
  module Models
    module Recognizers
      class Alvis < Annotator::Models::NcboAnnotator

        def initialize
          super()
        end

        def annotate_direct(text, options={})
          allAnnotations = {}

          return allAnnotations
        end

      end
    end
  end
end
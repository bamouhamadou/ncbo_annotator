module Annotator
  module Models
    module Recognizers
      class Alvis < Annotator::Models::NcboAnnotator

        def annotate_direct(text, options={})
          ontologies = options[:ontologies].is_a?(Array) ? options[:ontologies] : []
          semantic_types = options[:semantic_types].is_a?(Array) ? options[:semantic_types] : []
          use_semantic_types_hierarchy = options[:use_semantic_types_hierarchy] == true ? true : false
          filter_integers = options[:filter_integers] == true ? true : false
          min_term_size = options[:min_term_size].is_a?(Integer) ? options[:min_term_size] : nil
          whole_word_only = options[:whole_word_only] == false ? false : true
          with_synonyms = options[:with_synonyms] == false ? false : true
          longest_only = options[:longest_only] == true ? true : false

          allAnnotations = {}
          flattenedAnnotations = Array.new

          redis_data = Hash.new
          cur_inst = redis_current_instance()
          rawAnnotations = [{:id => "-4195353038606669928", :from => "1", :to => "8", :match => "ce qui match"}]

          # Get redis_data
          redis.pipelined {
            rawAnnotations.each do |ann|
              id = get_prefixed_id(cur_inst, ann[:id])
              redis_data[id] = { future: redis.hgetall(id) }
            end
          }
          sleep(1.0 / 150.0)

          # Wait if value not retrieved from redis
          redis_data.each do |k, v|
            while v[:future].value.is_a?(Redis::FutureNotReady)
              sleep(1.0 / 150.0)
            end
          end

          # Get matches values
          rawAnnotations.each do |ann|
            id = get_prefixed_id(cur_inst, ann[:id])
            matches = redis_data[id][:future].value

            # Iterate over matches retrieved from redis
            matches.each do |key, val|
              dataTypeVals = val.split(DATA_TYPE_DELIM)
              classSemanticTypes = (dataTypeVals.length > 1) ? dataTypeVals[1].split(LABEL_DELIM) : []
              allVals = dataTypeVals[0].split(OCCURRENCE_DELIM)

              # check that class semantic types contain at least one requested semantic type
              next if !semantic_types.empty? && (semantic_types & classSemanticTypes).empty?

              allVals.each do |eachVal|
                typeAndOnt = eachVal.split(LABEL_DELIM)
                recordType = typeAndOnt[0]
                next if recordType == Annotator::Annotation::MATCH_TYPES[:type_synonym] && !with_synonyms
                ontResourceId = typeAndOnt[1]
                acronym = ontResourceId.to_s.split('/')[-1]
                next if !ontologies.empty? && !ontologies.include?(ontResourceId) && !ontologies.include?(acronym)

                if (longest_only)
                  annotation = Annotation.new(key, ontResourceId)
                  annotation.add_annotation(ann[:from], ann[:to], typeAndOnt[0], ann[:match])
                  flattenedAnnotations << annotation
                else
                  id_group = ontResourceId + key

                  unless allAnnotations.include?(id_group)
                    allAnnotations[id_group] = Annotation.new(key, ontResourceId)
                  end
                  allAnnotations[id_group].add_annotation(ann[:from], ann[:to], typeAndOnt[0], ann[:match])
                end
              end
              puts "vals #{allAnnotations}"
            end
          end

          if (longest_only)
            flattenedAnnotations.sort! {|a, b| [a.annotations[0][:from], b.annotations[0][:to]] <=> [b.annotations[0][:from], a.annotations[0][:to]]}
            cur_min = 0;
            cur_max = 0;

            flattenedAnnotations.delete_if { |annotation|
              flag = true
              new_min = annotation.annotations[0][:from]
              new_max = annotation.annotations[0][:to]

              if (new_max > cur_max || (cur_min == new_min && cur_max == new_max))
                flag = false
                cur_min = new_min
                cur_max = new_max
              end
              flag
            }

            flattenedAnnotations.each do |annotation|
              id_group = annotation.annotatedClass.submission.ontology.id.to_s + annotation.annotatedClass.id.to_s

              if allAnnotations.include?(id_group)
                allAnnotations[id_group].add_annotation(annotation.annotations[0][:from], annotation.annotations[0][:to], annotation.annotations[0][:matchType], annotation.annotations[0][:text])
              else
                allAnnotations[id_group] = annotation
              end
            end
          end

          #allAnnotations[concat_concept_ont] = Annotation.new(concept_id, ont_id)

          return allAnnotations
        end

      end
    end
  end
end
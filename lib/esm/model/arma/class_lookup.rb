# frozen_string_literal: true

module ESM
  module Arma
    class ClassLookup
      Entry = Struct.new(:class_name, :display_name, :mod_name, :category_name).freeze

      #
      # Returns a struct that matches the provided class name.
      #
      # @param class_name [String, Symbol] The class name to find
      #
      # @return [Struct, nil] The class name data if found. nil if not found
      #
      def self.find(class_name)
        @lookup[class_name.downcase]
      end

      #
      # Used internally to cache the lookup data from the YML files
      #
      def self.cache
        @lookup = {}.with_indifferent_access

        # All classes are stored as YAML files in config/arma_classes
        # Convert the YAML file into a lookup table where the key is the class name and the value is an instance of CLASS_ENTRY
        Dir["#{File.expand_path("config/arma_classes")}/*.yml"].each do |file_path|
          yml = YAML.safe_load(File.read(file_path))

          yml.each do |_mod, mod_data|
            mod_name = mod_data["name"]

            mod_data["categories"].each do |_category, category_data|
              category_name = category_data["name"]

              category_data["entries"].each do |class_name, display_name|
                next if @lookup.key?(class_name)

                @lookup[class_name.downcase] = Entry.new(class_name, display_name, mod_name, category_name).freeze
              end
            end
          end
        end
      end
    end
  end
end

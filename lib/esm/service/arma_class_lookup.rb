# frozen_string_literal: true

module ESM
  module Service
    class ArmaClassLookup < ActiveSupport::HashWithIndifferentAccess
      CLASS_ENTRY = Struct.new(:class_name, :display_name, :mod_name, :category_name).freeze

      def initialize
        super

        # All classes are stored as YAML files in config/arma_classes
        path = File.expand_path("config/arma_classes")

        # Convert the YAML file into a lookup table where the key is the class name and the value is an instance of CLASS_ENTRY
        Dir["#{path}/*.yml"].each do |file_path|
          yml = YAML.safe_load(File.read(file_path))

          yml.each do |_mod, mod_data|
            mod_name = mod_data["name"]

            mod_data["categories"].each do |_category, category_data|
              category_name = category_data["name"]

              category_data["entries"].each do |class_name, display_name|
                next if self.key?(class_name)

                self[class_name.downcase] = CLASS_ENTRY.new(class_name, display_name, mod_name, category_name).freeze
              end
            end
          end
        end
      end
    end
  end
end

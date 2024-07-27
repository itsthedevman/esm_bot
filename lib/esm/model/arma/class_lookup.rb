# frozen_string_literal: true

module ESM
  module Arma
    class ClassLookup
      Entry = Data.define(:class_name, :display_name, :mod, :mod_name, :category, :category_name)

      CATEGORY_VEHICLES = %w[
        vehicle_static
        vehicle_car
        vehicle_tank
        vehicle_boat
        vehicle_helicopter
        vehicle_plan
        vehicle_misc
      ].freeze

      CATEGORY_EXILE = %w[
        exile_medical
        exile_container
        exile_construction
        exile_consumables
        exile_misc
      ].freeze

      CATEGORY_WEAPONS = %w[
        handguns
        items
        launchers
        machine_guns
        melee
        misc_weapons
        rifles
        sniper_rifles
        sub_machine_guns
      ].freeze

      CATEGORY_MAGAZINES = %w[
        magazines_explosives
        magazines_grenades
        magazines_rockets
        magazines
      ].freeze

      CATEGORY_CLOTHING = %w[
        clothing_backpacks
        clothing_headgear
        clothing_uniforms
        clothing_vests
      ].freeze

      CATEGORY_ATTACHMENTS = %w[
        attachment_bipods
        attachment_sights
        attachments_muzzles
        attachments_pointers
      ].freeze

      class << self
        attr_reader :lookup
        alias_method :all, :lookup

        def find(class_name)
          @lookup[class_name.to_s]
        end

        def where(**query)
          if !query.all? { |k, _v| Entry.members.include?(k.to_sym) }
            raise ESM::Exception::Error, "Invalid key or value is not a string"
          end

          @lookup.select do |class_name, entry|
            query.all? do |key, value|
              result = entry.send(key.to_sym)

              if value.is_a?(Array)
                value.any? { |v| result == v }
              else
                result == value
              end
            end
          end
        end

        private

        def cache
          # Temp storage for handling duplicates
          lookup = {}

          # All classes are stored as YAML files in config/arma_classes
          # Convert the YAML file into a lookup table where the key is the class name and the value is an instance of CLASS_ENTRY
          Dir["#{File.expand_path("config/arma_classes")}/*.yml"].each do |file_path|
            yml = YAML.safe_load_file(file_path)

            yml.each do |mod, mod_data|
              mod_name = mod_data["name"]

              mod_data["categories"].each do |category, category_data|
                category_name = category_data["name"]

                category_data["entries"].each do |class_name, display_name|
                  next if lookup.key?(class_name)

                  lookup[class_name] = Entry.new(
                    class_name,
                    display_name,
                    mod,
                    mod_name,
                    category,
                    category_name
                  )
                end
              end
            end
          end

          @lookup = lookup
          true
        end
      end

      # Cache the files meow!
      cache
    end
  end
end

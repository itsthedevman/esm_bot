# frozen_string_literal: true

module ESM
  class Embed
    EMPTY_SPACE = "\u200B"
    TAB = "#{EMPTY_SPACE}#{EMPTY_SPACE}#{EMPTY_SPACE}#{EMPTY_SPACE}"

    # Attributes that are available for building via Hash
    ATTRIBUTES = %i[author title description color fields]

    module Limit
      TITLE_LENGTH_MAX = 256
      DESCRIPTION_LENGTH_MAX = 2048
      FIELD_NAME_LENGTH_MAX = 256
      FIELD_VALUE_LENGTH_MAX = 1024
    end

    ###########################
    # Class methods
    ###########################

    #
    # Creates an embed from a preset
    #
    # @param type [Symbol] Template to build. Valid options: :info, :success, :error
    # @param ** [Hash] Any embed attributes to set
    # @param & [Block, nil] optional block that yields the new embed
    #
    # @return [ESM::Embed] The newly built instance
    #
    def self.build(type = nil, **, &)
      ESM::Embed.new(type, **, &)
    end

    #
    # Creates an embed from a Hash
    #
    # @param hash [Hash]
    # @param &block [Block, nil] Optional block that yields the new embed
    #
    # @return [ESM::Embed] The newly built instance
    #
    def self.from_hash(hash, &block)
      hash = hash.deep_symbolize_keys

      new do |embed|
        ###########
        # Author
        # Supports string or HashMap with full options
        if (author = hash[:author]) && author.present?
          author = ESM::Arma::HashMap.from(author).presence || {name: author}
          author = author.slice(:name, :url, :icon_url).symbolize_keys
          embed.set_author(**author)
        end

        ###########
        # Title
        if (title = hash[:title]) && title.present?
          embed.title = title.to_s
        end

        ###########
        # Description
        if (description = hash[:description]) && description.present?
          embed.description = description.to_s
        end

        ###########
        # Color
        color = hash[:color]
        embed.color =
          if ESM::Regex::HEX_COLOR.match?(color)
            color
          elsif color && ESM::Color::Toast.const_defined?(color.upcase)
            ESM::Color::Toast.const_get(color.upcase)
          else
            ESM::Color.random
          end

        ###########
        # Fields
        if (fields = hash[:fields]) && fields.is_a?(Array)
          fields.each do |field|
            case field
            when Hash
              name = field[:name].to_s
              value = field[:value]
              inline = field[:inline] || false
            when Data, Struct, OpenStruct
              name = field.name.to_s
              value = field.value
              inline = field.inline || false
            when Array
              name, value, inline = field
              inline ||= false
            else
              next
            end

            # Transform the hash keys/values into a "list"
            value =
              if value.is_a?(Hash)
                value.join_map("\n") do |key, value|
                  "**#{key.to_s.humanize(keep_id_suffix: true)}:** #{value}"
                end
              else
                value.to_s
              end

            embed.add_field(name:, value:, inline:)
          end
        end

        yield(embed) if block
      end
    end

    def self.from_hash!(hash)
      # Missing data or extra data? That's a paddling
      embed_data = hash.slice(*ATTRIBUTES)

      if embed_data.blank?
        raise ArgumentError, I18n.translate(
          "exceptions.embed.missing_attributes",
          attributes: Embed::ATTRIBUTES.map(&:quoted).to_sentence
        )
      end

      invalid_attributes = hash.keys - embed_data.keys

      if invalid_attributes.size > 0
        raise ArgumentError, I18n.translate(
          "exceptions.embed.invalid_attributes",
          attributes: invalid_attributes.map(&:quoted).to_sentence
        )
      end

      from_hash(embed_data)
    end

    ###########################
    # Instance methods
    ###########################
    attr_reader :title, :description, :image, :thumbnail, :footer, :color
    attr_accessor :fields, :author, :url, :timestamp

    def initialize(type = nil, attributes = {}, &block)
      @title = nil
      @description = nil
      @fields = []
      @footer = nil
      @author = nil
      @image = nil
      @thumbnail = nil
      @color = ESM::Color.random
      @url = nil
      @timestamp = DateTime.now

      if block
        yield(self)
      else
        build_from_template(type, **attributes)
      end
    end

    def title=(text)
      text ||= ""

      @title = text.truncate(Limit::TITLE_LENGTH_MAX, separator: " ")
    end

    def description=(text)
      text ||= ""

      text = text.join("\n") if text.is_a?(Array)
      @description = text.truncate(Limit::DESCRIPTION_LENGTH_MAX)
    end

    def add_field(value:, name: nil, inline: false)
      # This will make the name appear empty
      name = EMPTY_SPACE if name.nil?

      # Discord won't send messages that have an empty field. This forces the value to be appear empty, and Discord will accept it.
      value = EMPTY_SPACE if value.blank?

      if value.is_a?(Array)
        add_field_array(name:, values: value, inline:)
      else
        store_field(name:, value:, inline:)
      end

      self
    end

    def set_footer(text: nil, icon_url: nil)
      @footer = Discordrb::Webhooks::EmbedFooter.new(text: text, icon_url: icon_url)
    end

    def footer=(text)
      set_footer(text: text)
    end

    def set_author(name:, url: nil, icon_url: nil)
      @author = Discordrb::Webhooks::EmbedAuthor.new(name: name, url: url, icon_url: icon_url)
    end

    def image=(url)
      @image = Discordrb::Webhooks::EmbedImage.new(url: url)
    end

    def thumbnail=(url)
      @thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: url)
    end

    def color=(color)
      @color =
        if color.is_a?(Symbol) && ESM::Color::Toast.const_defined?(color.to_s.upcase)
          ESM::Color::Toast.const_get(color.to_s.upcase)
        else
          color
        end
    end

    def transfer(embed)
      # And you can't do `embed = new_embed`
      embed.title = title if title
      embed.description = description if description
      embed.url = url if url
      embed.timestamp = timestamp if timestamp
      embed.color = color if color
      embed.footer = footer if footer
      embed.image = image if image
      embed.thumbnail = thumbnail if thumbnail
      embed.author = author if author
      embed.fields = fields if fields

      self
    end

    def to_s
      output = ""
      output += "Title (#{title.size}): #{title}\n" if title
      output += "Description (#{description.size}): #{description}\n" if description

      if fields
        output += "Fields:\n"
        fields.each_with_index do |field, index|
          output += "\t##{index + 1}"
          output += " <inline>" if field.inline

          output += "\n\t  Name (#{field.name.size}): #{field.name}"
          output += "\n\t  Value (#{field.value.size}): #{field.value}\n"
        end
      end

      # Add the metadata
      if metadata?
        output += "Metadata:\n"
        output += "\tTimestamp: #{timestamp}\n" if timestamp
        output += "\tColor: #{color}\n" if color
        output += "\tImage: #{image.url}\n" if image
        output += "\tThumbnail: #{thumbnail.url}\n" if thumbnail
        output += "\tURL: #{url}\n" if url
        output += "\tFooter: #{footer.text}" if footer
      end

      output
    end

    def to_h
      {
        title: title,
        description: description,
        timestamp: timestamp,
        color: color,
        footer: footer&.text,
        fields: fields.map { |f| {name: f.name, value: f.value, inline: f.inline} },
        author: author&.to_hash,
        thumbnail: thumbnail,
        image: image,
        url: url
      }
    end

    def for_discord_embed
      {
        title: title,
        description: description,
        timestamp: timestamp.to_s,
        color: color&.sub("#", "")&.to_i(16),
        footer: footer&.to_hash,
        fields: fields.map(&:to_hash),
        author: author&.to_hash,
        thumbnail: thumbnail&.to_hash,
        image: image&.to_hash,
        url: url&.to_hash
      }
    end

    def build_from_template(type, **attributes)
      case type
      when :info
        self.color = :blue
      when :error
        self.color = :red
      when :success
        self.color = :green
      end

      attributes.each do |attr_name, attr_value|
        send(:"#{attr_name}=", attr_value)
      end
    end

    private

    def metadata?
      timestamp.present? || color.present? || image.present? || thumbnail.present? || url.present?
    end

    def add_field_array(name:, values:, inline:)
      field_values = if values.sum(&:size) < Limit::FIELD_VALUE_LENGTH_MAX
        [values]
      else
        field_values = []
        field_counter = 0

        values.each do |value|
          field_content = field_values[field_counter] ||= []

          # If this value is too large for the current field, redo this iteration again but with a new field
          if (field_content.total_size + value.size) >= Limit::FIELD_VALUE_LENGTH_MAX
            field_counter += 1
            redo
          end

          field_content << value
        end

        field_values
      end

      field_values.each_with_index do |values, index|
        store_field(name: index.zero? ? name : EMPTY_SPACE, value: values.join("\n\n"), inline: inline)
      end
    end

    def store_field(name:, value:, inline:)
      # to_s to ensure a string
      @fields << Discordrb::Webhooks::EmbedField.new(
        name: name.to_s.truncate(Limit::FIELD_NAME_LENGTH_MAX, separator: "\n"),
        value: value.to_s.truncate(Limit::FIELD_VALUE_LENGTH_MAX, separator: "\n"),
        inline: inline
      )
    end
  end
end

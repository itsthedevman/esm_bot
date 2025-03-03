# frozen_string_literal: true

class Array
  def to_arma_hashmap
    ESM::Arma::HashMap.from(self)
  end

  def join_map(join_with = "", &)
    filter_map(&).join(join_with)
  end

  # Adds up all the sizes of every element inside the array
  def total_size
    reduce(0) do |total, i|
      size =
        case i
        when Array
          i.total_size
        when Integer
          i
        else
          i.size
        end

      total + size
    end
  end
end

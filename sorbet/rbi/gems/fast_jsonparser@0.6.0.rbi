# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `fast_jsonparser` gem.
# Please instead update this file by running `bin/tapioca gem fast_jsonparser`.

# source://fast_jsonparser//lib/fast_jsonparser/version.rb#1
module FastJsonparser
  class << self
    # source://fast_jsonparser//lib/fast_jsonparser.rb#18
    def load(source, symbolize_keys: T.unsafe(nil)); end

    # source://fast_jsonparser//lib/fast_jsonparser.rb#22
    def load_many(source, symbolize_keys: T.unsafe(nil), batch_size: T.unsafe(nil), &block); end

    # source://fast_jsonparser//lib/fast_jsonparser.rb#14
    def parse(source, symbolize_keys: T.unsafe(nil)); end

    private

    # source://fast_jsonparser//lib/fast_jsonparser.rb#35
    def parser; end
  end
end

# source://fast_jsonparser//lib/fast_jsonparser.rb#9
class FastJsonparser::BatchSizeTooSmall < ::FastJsonparser::Error; end

# from include/simdjson/dom/parser.h
#
# source://fast_jsonparser//lib/fast_jsonparser.rb#11
FastJsonparser::DEFAULT_BATCH_SIZE = T.let(T.unsafe(nil), Integer)

# source://fast_jsonparser//lib/fast_jsonparser.rb#6
class FastJsonparser::Error < ::StandardError; end

# source://fast_jsonparser//lib/fast_jsonparser.rb#40
class FastJsonparser::Native
  def _load(_arg0, _arg1); end
  def _load_many(_arg0, _arg1, _arg2); end
  def _parse(_arg0, _arg1); end
end

# source://fast_jsonparser//lib/fast_jsonparser.rb#7
class FastJsonparser::ParseError < ::FastJsonparser::Error; end

# source://fast_jsonparser//lib/fast_jsonparser.rb#8
class FastJsonparser::UnknownError < ::FastJsonparser::Error; end

# source://fast_jsonparser//lib/fast_jsonparser/version.rb#2
FastJsonparser::VERSION = T.let(T.unsafe(nil), String)

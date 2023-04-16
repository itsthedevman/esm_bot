# frozen_string_literal: true

class MysqlRecord < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :arma_test
end

# frozen_string_literal: true

ESM.load! unless ESM.loader.setup? && ESM.loader.eager_loaded?

#############################
# Initializers
#############################
ESM::Arma::ClassLookup.cache

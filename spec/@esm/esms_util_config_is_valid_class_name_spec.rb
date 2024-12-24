# frozen_string_literal: true

describe "ESMs_util_config_isValidClassName", :requires_connection, v2: true do
  include_context "connection"

  let(:class_name) { "" }

  subject(:is_valid_classname) do
    execute_sqf!("#{class_name.quoted} call ESMs_util_config_isValidClassName")
  end

  context "when the class name is valid" do
    let!(:class_name) { ESM::Arma::ClassLookup.where(mod: "exile").keys.sample }

    it { is_expected.to be(true) }
  end

  context "when the class name is invalid" do
    let!(:class_name) { "arifle_NoobDestroyer" }

    it { is_expected.to be(false) }
  end
end

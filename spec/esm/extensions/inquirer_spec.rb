# frozen_string_literal: true

describe Inquirer do
  context "when there is only one predicate provided" do
    subject(:inquirer) { described_class.new(:foo) }

    it "initializes" do
      expect(inquirer).to be_instance_of(described_class)
      expect(inquirer.foo?).to be(false)
    end
  end

  context "when there are more than one predicates provided" do
    subject(:inquirer) { described_class.new(:foo, :bar) }

    it "initializes" do
      expect(inquirer).to be_instance_of(described_class)
      expect(inquirer.foo?).to be(false)
      expect(inquirer.bar?).to be(false)
    end
  end

  context "when a symbol is provided as the default" do
    subject(:inquirer) { described_class.new(:foo, :bar, default: :bar) }

    it "sets the provided predicate to true" do
      expect(inquirer.foo?).to be(false)
      expect(inquirer.bar?).to be(true)
    end
  end

  context "when an array is provided as the default" do
    subject(:inquirer) { described_class.new(:foo, :bar, :baz, default: [:foo, :bar]) }

    it "sets all provided predicates to true" do
      expect(inquirer.foo?).to be(true)
      expect(inquirer.bar?).to be(true)
      expect(inquirer.baz?).to be(false)
    end
  end

  context "when the predicate is set after initialization" do
    subject(:inquirer) { described_class.new(:foo, :bar, :baz) }

    it "sets all provided predicates to true" do
      expect(inquirer.foo?).to be(false)
      expect(inquirer.bar?).to be(false)
      expect(inquirer.baz?).to be(false)

      inquirer.set(:foo, :baz)

      expect(inquirer.foo?).to be(true)
      expect(inquirer.bar?).to be(false)
      expect(inquirer.baz?).to be(true)
    end
  end
end

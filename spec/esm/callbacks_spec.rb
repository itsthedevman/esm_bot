# frozen_string_literal: true

describe ESM::Callbacks do
  let(:object) { Callback.new }

  before :each do
    object.instance_variable_set("@tracker", [])
  end

  describe "#register_callbacks" do
    it "should have registered callbacks" do
      callbacks = object.class.__callbacks
      expect(callbacks).not_to be_blank

      expect(callbacks).to eq({ before_execute: [:method_to_call_from_class], after_execute: [] })
    end
  end

  describe "#add_callback" do
    it "should add a callback (method)" do
      object.add_callback(:before_execute, :method_to_call_on_before_execute)
      callbacks = object.__callbacks[:before_execute]
      expect(callbacks).not_to be_blank
      expect(callbacks.size).to eq(2)
      expect(callbacks).to eq([:method_to_call_from_class, :method_to_call_on_before_execute])
    end

    it "should add a callback (block)" do
      object.add_callback(:before_execute) do
        puts "hello"
      end

      callbacks = object.__callbacks[:before_execute]
      expect(callbacks.size).to eq(2)
      expect(callbacks).not_to be_blank
    end

    it "should support adding callbacks on the class level" do
      expect(object.class.respond_to?(:add_callback)).to eq(true)
    end
  end

  describe "#run_callback" do
    it "should add and run the callbacks" do
      tracker = object.instance_variable_get("@tracker")
      object.add_callback(:before_execute, :method_to_call_on_before_execute)
      object.add_callback(:after_execute, :method_to_call_on_after_execute)
      object.add_callback(:before_execute) { tracker << "before_execute_2" }
      object.add_callback(:after_execute) { tracker << "after_execute_2" }

      expect { object.run_callback(:before_execute) }.not_to raise_error
      expect { object.run_callback(:after_execute) }.not_to raise_error

      expect(tracker).to eq([
        "from_class",
        "before_execute",
        "before_execute_2",
        "after_execute",
        "after_execute_2"
      ])
    end
  end
end

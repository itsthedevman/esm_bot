# frozen_string_literal: true

class Callback
  include ESM::Callbacks
  register_callbacks :before_execute, :after_execute

  def method_to_call_on_before_execute
    @tracker << "before_execute"
  end

  def method_to_call_on_after_execute
    @tracker << "after_execute"
  end
end

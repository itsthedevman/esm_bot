module ESM
  module Command
    class Base
      attr_writer :limit_to, :requires, :event

      alias_method :old_execute, :execute
      def execute(event, raise_error: true)
        old_execute(event)
      rescue => e
        handle_error(e, raise_error: raise_error)
      end
    end
  end
end

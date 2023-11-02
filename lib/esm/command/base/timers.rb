# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Timers < Hash
        def initialize(command_name)
          @command_name = command_name
          super
        end

        def reset_all!
          values.each(&:reset!)
        end

        def stop_all!
          values.each(&:stop!)
        end

        def to_h
          transform_values(&:to_h)
        end

        def time!(timer_name, &block)
          timer = create_timer(timer_name)

          timer.start!
          yield
          timer.stop!

          info!(
            timer: timer_name,
            command: @command_name,
            time_elapsed: "#{timer.time_elapsed * 1000} ms"
          )

          nil
        end

        def total
          values.sum(&:time_elapsed)
        end

        private

        def create_timer(name)
          name = name.to_sym

          timer = Timer.new

          self[name] = timer
          self.class.define_method(name) { self[name] }

          timer
        end
      end
    end
  end
end

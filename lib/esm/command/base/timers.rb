# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Timers
        def initialize(command_name)
          @command_name = command_name

          @timers = {
            on_execute: Timer.new,
            on_response: Timer.new,
            from_discord: Timer.new,
            from_server: Timer.new,
            from_request: Timer.new
          }

          @timers.keys.each do |key|
            self.class.define_method(key) { @timers[key] }
          end
        end

        def reset_all!
          @timers.values.each(&:reset!)
        end

        def stop_all!
          @timers.values.each(&:stop!)
        end

        def to_h
          @timers.transform_values(&:to_h)
        end

        def time!(timer_name, &block)
          timer = public_send(timer_name)
          if timer.nil?
            raise "Invalid timer name: #{timer_name}. Expected one of #{@timers.keys.to_sentence(last_word_connector: ", or ")}"
          end

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
      end
    end
  end
end

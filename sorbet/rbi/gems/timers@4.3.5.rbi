# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `timers` gem.
# Please instead update this file by running `bin/tapioca gem timers`.

# source://timers//lib/timers/version.rb#8
module Timers; end

# Maintains a PriorityHeap of events ordered on time, which can be cancelled.
#
# source://timers//lib/timers/events.rb#16
class Timers::Events
  # @return [Events] a new instance of Events
  #
  # source://timers//lib/timers/events.rb#51
  def initialize; end

  # Fire all handles for which Handle#time is less than the given time.
  #
  # source://timers//lib/timers/events.rb#85
  def fire(time); end

  # Returns the first non-cancelled handle.
  #
  # source://timers//lib/timers/events.rb#70
  def first; end

  # Add an event at the given time.
  #
  # source://timers//lib/timers/events.rb#59
  def schedule(time, callback); end

  # Returns the number of pending (possibly cancelled) events.
  #
  # source://timers//lib/timers/events.rb#80
  def size; end

  private

  # source://timers//lib/timers/events.rb#105
  def flush!; end

  # Move all non-cancelled timers from the pending queue to the priority heap
  #
  # source://timers//lib/timers/events.rb#97
  def merge!; end
end

# Represents a cancellable handle for a specific timer event.
#
# source://timers//lib/timers/events.rb#18
class Timers::Events::Handle
  include ::Comparable

  # @return [Handle] a new instance of Handle
  #
  # source://timers//lib/timers/events.rb#21
  def initialize(time, callback); end

  # source://timers//lib/timers/events.rb#41
  def <=>(other); end

  # Cancel this timer, O(1).
  #
  # source://timers//lib/timers/events.rb#30
  def cancel!; end

  # Has this timer been cancelled? Cancelled timer's don't fire.
  #
  # @return [Boolean]
  #
  # source://timers//lib/timers/events.rb#37
  def cancelled?; end

  # Fire the callback if not cancelled with the given time parameter.
  #
  # source://timers//lib/timers/events.rb#46
  def fire(time); end

  # The absolute time that the handle should be fired at.
  #
  # source://timers//lib/timers/events.rb#27
  def time; end
end

# A collection of timers which may fire at different times
#
# source://timers//lib/timers/group.rb#18
class Timers::Group
  include ::Enumerable
  extend ::Forwardable

  # @return [Group] a new instance of Group
  #
  # source://timers//lib/timers/group.rb#24
  def initialize; end

  # Call the given block after the given interval. The first argument will be
  # the time at which the group was asked to fire timers for.
  #
  # source://timers//lib/timers/group.rb#45
  def after(interval, &block); end

  # Cancel all timers.
  #
  # source://timers//lib/timers/group.rb#124
  def cancel; end

  # Resume all timers.
  #
  # source://timers//lib/timers/group.rb#110
  def continue; end

  # The group's current time.
  #
  # source://timers//lib/timers/group.rb#129
  def current_offset; end

  # Delay all timers.
  #
  # source://timers//lib/timers/group.rb#117
  def delay(seconds); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def each(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def empty?(*args, &block); end

  # Scheduled events:
  #
  # source://timers//lib/timers/group.rb#35
  def events; end

  # Call the given block periodically at the given interval. The first
  # argument will be the time at which the group was asked to fire timers for.
  #
  # source://timers//lib/timers/group.rb#58
  def every(interval, recur = T.unsafe(nil), &block); end

  # Fire all timers that are ready.
  #
  # source://timers//lib/timers/group.rb#100
  def fire(offset = T.unsafe(nil)); end

  # Call the given block immediately, and then after the given interval. The first
  # argument will be the time at which the group was asked to fire timers for.
  #
  # source://timers//lib/timers/group.rb#51
  def now_and_after(interval, &block); end

  # Call the given block immediately, and then periodically at the given interval. The first
  # argument will be the time at which the group was asked to fire timers for.
  #
  # source://timers//lib/timers/group.rb#64
  def now_and_every(interval, recur = T.unsafe(nil), &block); end

  # Pause all timers.
  #
  # source://timers//lib/timers/group.rb#105
  def pause; end

  # Paused timers:
  #
  # source://timers//lib/timers/group.rb#41
  def paused_timers; end

  # Resume all timers.
  #
  # source://timers//lib/timers/group.rb#110
  def resume; end

  # Active timers:
  #
  # source://timers//lib/timers/group.rb#38
  def timers; end

  # Wait for the next timer and fire it. Can take a block, which should behave
  # like sleep(n), except that n may be nil (sleep forever) or a negative
  # number (fire immediately after return).
  #
  # source://timers//lib/timers/group.rb#72
  def wait; end

  # Interval to wait until when the next timer will fire.
  # - nil: no timers
  # - -ve: timers expired already
  # -   0: timers ready to fire
  # - +ve: timers waiting to fire
  #
  # source://timers//lib/timers/group.rb#94
  def wait_interval(offset = T.unsafe(nil)); end
end

# A collection of timers which may fire at different times
#
# source://timers//lib/timers/interval.rb#8
class Timers::Interval
  # Get the current elapsed monotonic time.
  #
  # @return [Interval] a new instance of Interval
  #
  # source://timers//lib/timers/interval.rb#10
  def initialize; end

  # source://timers//lib/timers/interval.rb#15
  def start; end

  # source://timers//lib/timers/interval.rb#21
  def stop; end

  # source://timers//lib/timers/interval.rb#29
  def to_f; end

  protected

  # source://timers//lib/timers/interval.rb#33
  def duration; end

  # source://timers//lib/timers/interval.rb#37
  def now; end
end

# A priority queue implementation using a standard binary minheap. It uses straight comparison
# of its contents to determine priority. This works because a Handle from Timers::Events implements
# the '<' operation by comparing the expiry time.
# See <https://en.wikipedia.org/wiki/Binary_heap> for explanations of the main methods.
#
# source://timers//lib/timers/priority_heap.rb#12
class Timers::PriorityHeap
  # @return [PriorityHeap] a new instance of PriorityHeap
  #
  # source://timers//lib/timers/priority_heap.rb#13
  def initialize; end

  # Empties out the heap, discarding all elements
  #
  # source://timers//lib/timers/priority_heap.rb#74
  def clear!; end

  # Returns the earliest timer or nil if the heap is empty.
  #
  # source://timers//lib/timers/priority_heap.rb#21
  def peek; end

  # Returns the earliest timer if the heap is non-empty and removes it from the heap.
  # Returns nil if the heap is empty. (and doesn't change the heap in that case)
  #
  # source://timers//lib/timers/priority_heap.rb#32
  def pop; end

  # Inserts a new timer into the heap, then rearranges elements until the heap invariant is true again.
  #
  # source://timers//lib/timers/priority_heap.rb#61
  def push(element); end

  # Returns the number of elements in the heap
  #
  # source://timers//lib/timers/priority_heap.rb#26
  def size; end

  # Validate the heap invariant. Every element except the root must not be smaller than
  # its parent element. Note that it MAY be equal.
  #
  # @return [Boolean]
  #
  # source://timers//lib/timers/priority_heap.rb#80
  def valid?; end

  private

  # source://timers//lib/timers/priority_heap.rb#107
  def bubble_down(index); end

  # source://timers//lib/timers/priority_heap.rb#91
  def bubble_up(index); end

  # source://timers//lib/timers/priority_heap.rb#87
  def swap(i, j); end
end

# An individual timer set to fire a given proc at a given time. A timer is
# always connected to a Timer::Group but it would ONLY be in @group.timers
# if it also has a @handle specified. Otherwise it is either PAUSED or has
# been FIRED and is not recurring. You can manually enter this state by
# calling #cancel and resume normal operation by calling #reset.
#
# source://timers//lib/timers/timer.rb#16
class Timers::Timer
  include ::Comparable

  # @return [Timer] a new instance of Timer
  #
  # source://timers//lib/timers/timer.rb#20
  def initialize(group, interval, recurring = T.unsafe(nil), offset = T.unsafe(nil), &block); end

  # Fire the block.
  #
  # source://timers//lib/timers/timer.rb#96
  def call(offset = T.unsafe(nil)); end

  # Cancel this timer. Do not call while paused.
  #
  # source://timers//lib/timers/timer.rb#69
  def cancel; end

  # source://timers//lib/timers/timer.rb#48
  def continue; end

  # Extend this timer
  #
  # source://timers//lib/timers/timer.rb#60
  def delay(seconds); end

  # Fire the block.
  #
  # source://timers//lib/timers/timer.rb#96
  def fire(offset = T.unsafe(nil)); end

  # Number of seconds until next fire / since last fire
  #
  # source://timers//lib/timers/timer.rb#114
  def fires_in; end

  # Inspect a timer
  #
  # source://timers//lib/timers/timer.rb#119
  def inspect; end

  # Returns the value of attribute interval.
  #
  # source://timers//lib/timers/timer.rb#18
  def interval; end

  # Returns the value of attribute offset.
  #
  # source://timers//lib/timers/timer.rb#18
  def offset; end

  # source://timers//lib/timers/timer.rb#38
  def pause; end

  # @return [Boolean]
  #
  # source://timers//lib/timers/timer.rb#34
  def paused?; end

  # Returns the value of attribute recurring.
  #
  # source://timers//lib/timers/timer.rb#18
  def recurring; end

  # Reset this timer. Do not call while paused.
  #
  # @param offset [Numeric] the duration to add to the timer.
  #
  # source://timers//lib/timers/timer.rb#81
  def reset(offset = T.unsafe(nil)); end

  # source://timers//lib/timers/timer.rb#48
  def resume; end
end

# source://timers//lib/timers/version.rb#9
Timers::VERSION = T.let(T.unsafe(nil), String)

# An exclusive, monotonic timeout class.
#
# source://timers//lib/timers/wait.rb#13
class Timers::Wait
  # @return [Wait] a new instance of Wait
  #
  # source://timers//lib/timers/wait.rb#26
  def initialize(duration); end

  # Returns the value of attribute duration.
  #
  # source://timers//lib/timers/wait.rb#31
  def duration; end

  # Returns the value of attribute remaining.
  #
  # source://timers//lib/timers/wait.rb#32
  def remaining; end

  # Yields while time remains for work to be done:
  #
  # source://timers//lib/timers/wait.rb#35
  def while_time_remaining; end

  private

  # @return [Boolean]
  #
  # source://timers//lib/timers/wait.rb#47
  def time_remaining?; end

  class << self
    # source://timers//lib/timers/wait.rb#14
    def for(duration, &block); end
  end
end

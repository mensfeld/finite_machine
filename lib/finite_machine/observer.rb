# encoding: utf-8

module FiniteMachine

  # A class responsible for observing state changes
  class Observer
    include Threadable

    # The current state machine
    attr_threadsafe :machine

    # The hooks to trigger around the transition lifecycle.
    attr_threadsafe :hooks

    # Initialize an Observer
    #
    # @api public
    def initialize(machine)
      @machine = machine
      @machine.subscribe(self)

      @hooks = Hash.new { |events_hash, event_type|
        events_hash[event_type] = Hash.new { |state_hash, name|
          state_hash[name] = []
        }
      }
    end

    # Evaluate in current context
    #
    # @api private
    def call(&block)
      instance_eval(&block)
    end

    # Register callback for a given event.
    #
    # @param [Symbol] event_type
    # @param [Symbol] name
    # @param [Proc]   callback
    #
    # @api public
    def on(event_type = ANY_EVENT, name = ANY_STATE, &callback)
      ensure_valid_callback_name!(name)
      hooks[event_type][name] << callback
    end

    def on_enter(*args, &callback)
      if machine.states.any? { |state| state == args.first }
        on :enterstate, *args, &callback
      elsif machine.event_names.any? { |name| name == args.first }
        on :enteraction, *args, &callback
      else
        on :enterstate, *args, &callback
        on :enteraction, *args, &callback
      end
    end

    def on_transition(*args, &callback)
      if machine.states.any? { |state| state == args.first }
        on :transitionstate, *args, &callback
      elsif machine.event_names.any? { |name| name == args.first }
        on :transitionaction, *args, &callback
      else
        on :transitionstate, *args, &callback
        on :transitionaction, *args, &callback
      end
    end

    def on_exit(*args, &callback)
      if machine.states.any? { |state| state == args.first }
        on :exitstate, *args, &callback
      elsif machine.event_names.any? { |name| name == args.first }
        on :exitaction, *args, &callback
      else
        on :exitstate, *args, &callback
        on :exitaction, *args, &callback
      end
    end

    def method_missing(method_name, *args, &block)
      _, event_name, callback_name = *method_name.to_s.match(/^(on_\w+?)_(\w+)$/)
      if callback_names.include?(callback_name.to_sym)
        send(event_name, callback_name.to_sym, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      _, callback_name = *method_name.to_s.match(/^(on_\w+?)_(\w+)$/)
      callback_names.include?(callback_name.to_sym)
    end

    TransitionEvent = Struct.new(:from, :to, :name) do
      def build(_transition)
        self.from = _transition.from.first
        self.to   = _transition.to
        self.name = _transition.name
      end
    end

    def run_callback(hook, event)
      trans_event = TransitionEvent.new
      trans_event.build(event.transition)
      hook.call(trans_event, *event.data)
    end

    def trigger(event)
      [event.type, ANY_EVENT].each do |event_type|
        [event.state, ANY_STATE].each do |event_state|
          hooks[event_type][event_state].each do |hook|
            run_callback hook, event
          end
        end
      end
    end

    private

    def callback_names
      @callback_names = Set.new
      @callback_names.merge machine.event_names
      @callback_names.merge machine.states
      @callback_names.merge [ANY_STATE, ANY_EVENT]
    end

    def ensure_valid_callback_name!(name)
      unless callback_names.include?(name)
        raise InvalidCallbackNameError, "#{name} is not a valid callback name." +
          " Valid callback names are #{callback_names.to_a.inspect}"
      end
    end

  end # Observer
end # FiniteMachine

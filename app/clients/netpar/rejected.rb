module Netpar
  # NETPAR odrzucił dane (HTTP 422) – np. brak wolnych miejsc w sesji. `messages` – komunikaty z NETPAR.
  class Rejected < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = Array(messages).flatten.compact.map(&:to_s)
      super("NETPAR odrzucił dane: #{@messages.join('; ')}")
    end
  end
end

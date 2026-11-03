# Base class for multi-step business operations.
#
#   result = Betting::PlaceBet.call(user:, market:, outcome_id:, stake:)
#   result.success? # => true / false
#   result.value    # => whatever #perform returned
#   result.error    # => human-readable message when it failed
#
# Subclasses implement #perform and call #fail! to abort. Because fail! raises,
# calling it inside a transaction block rolls that transaction back.
class ApplicationService
  class Failure < StandardError; end

  Result = Data.define(:value, :error) do
    def success?
      error.nil?
    end

    def failure?
      !success?
    end
  end

  def self.call(...)
    new(...).call
  end

  def call
    Result.new(value: perform, error: nil)
  rescue Failure => e
    Result.new(value: nil, error: e.message)
  end

  private
    def fail!(message)
      raise Failure, message
    end
end

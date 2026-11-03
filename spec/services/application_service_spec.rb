require "rails_helper"

RSpec.describe ApplicationService do
  let(:service_class) do
    Class.new(described_class) do
      def initialize(succeed:)
        @succeed = succeed
      end

      def perform
        fail!("Nope") unless @succeed
        :done
      end
    end
  end

  it "wraps the return value of #perform in a successful result" do
    result = service_class.call(succeed: true)

    expect(result).to be_success
    expect(result).not_to be_failure
    expect(result.value).to eq(:done)
  end

  it "turns fail! into a failed result with the message" do
    result = service_class.call(succeed: false)

    expect(result).to be_failure
    expect(result.error).to eq("Nope")
    expect(result.value).to be_nil
  end
end

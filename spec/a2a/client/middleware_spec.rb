# frozen_string_literal: true

require "spec_helper"
require "a2a/client/middleware"

RSpec.describe A2a::Client::CallContext do
  describe "#initialize" do
    it "creates context with empty state by default" do
      context = described_class.new
      expect(context.state).to eq({})
    end

    it "accepts initial state" do
      state = { key: "value" }
      context = described_class.new(state)
      expect(context.state).to eq(state)
    end

    it "allows state modification" do
      context = described_class.new
      context.state[:new_key] = "new_value"
      expect(context.state[:new_key]).to eq("new_value")
    end
  end
end

RSpec.describe A2a::Client::CallInterceptor do
  let(:interceptor) { described_class.new }

  it "raises NotImplementedError when intercept is called" do
    expect do
      interceptor.intercept("method", {}, {})
    end.to raise_error(NotImplementedError, "Subclasses must implement #intercept")
  end
end

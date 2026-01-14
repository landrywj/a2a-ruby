# frozen_string_literal: true

require "spec_helper"
require "a2a/client/errors"

RSpec.describe A2a::Client::Error do
  it "is a StandardError" do
    expect(described_class.superclass).to eq(StandardError)
  end
end

RSpec.describe A2a::Client::HTTPError do
  let(:error) { described_class.new(404, "Not Found") }

  it "inherits from Error" do
    expect(described_class.superclass).to eq(A2a::Client::Error)
  end

  it "has status_code and message attributes" do
    expect(error.status_code).to eq(404)
    expect(error.message).to eq("Not Found")
  end

  it "formats error message correctly" do
    expect(error.to_s).to eq("HTTP Error 404: Not Found")
  end
end

RSpec.describe A2a::Client::JSONError do
  let(:error) { described_class.new("Invalid JSON") }

  it "inherits from Error" do
    expect(described_class.superclass).to eq(A2a::Client::Error)
  end

  it "has message attribute" do
    expect(error.message).to eq("Invalid JSON")
  end

  it "formats error message correctly" do
    expect(error.to_s).to eq("JSON Error: Invalid JSON")
  end
end

RSpec.describe A2a::Client::TimeoutError do
  let(:error) { described_class.new("Request timed out") }

  it "inherits from Error" do
    expect(described_class.superclass).to eq(A2a::Client::Error)
  end

  it "has message attribute" do
    expect(error.message).to eq("Request timed out")
  end

  it "formats error message correctly" do
    expect(error.to_s).to eq("Timeout Error: Request timed out")
  end
end

RSpec.describe A2a::Client::InvalidStateError do
  let(:error) { described_class.new("Client is closed") }

  it "inherits from Error" do
    expect(described_class.superclass).to eq(A2a::Client::Error)
  end

  it "has message attribute" do
    expect(error.message).to eq("Client is closed")
  end

  it "formats error message correctly" do
    expect(error.to_s).to eq("Invalid state error: Client is closed")
  end
end

RSpec.describe A2a::Client::InvalidArgsError do
  let(:error) { described_class.new("Invalid parameter") }

  it "inherits from Error" do
    expect(described_class.superclass).to eq(A2a::Client::Error)
  end

  it "has message attribute" do
    expect(error.message).to eq("Invalid parameter")
  end

  it "formats error message correctly" do
    expect(error.to_s).to eq("Invalid arguments error: Invalid parameter")
  end
end

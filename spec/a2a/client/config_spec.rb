# frozen_string_literal: true

require "spec_helper"
require "a2a/client/config"

RSpec.describe A2a::Client::Config do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new
      expect(config.streaming).to be(true)
      expect(config.polling).to be(false)
      expect(config.httpx_client).to be_nil
      expect(config.grpc_channel_factory).to be_nil
      expect(config.supported_transports).to eq([])
      expect(config.use_client_preference).to be(false)
      expect(config.accepted_output_modes).to eq([])
      expect(config.push_notification_configs).to eq([])
      expect(config.extensions).to eq([])
    end

    it "accepts custom values" do
      config = described_class.new(
        streaming: false,
        polling: true,
        supported_transports: ["JSONRPC"],
        use_client_preference: true,
        accepted_output_modes: ["text"],
        extensions: ["ext1"]
      )
      expect(config.streaming).to be(false)
      expect(config.polling).to be(true)
      expect(config.supported_transports).to eq(["JSONRPC"])
      expect(config.use_client_preference).to be(true)
      expect(config.accepted_output_modes).to eq(["text"])
      expect(config.extensions).to eq(["ext1"])
    end
  end
end

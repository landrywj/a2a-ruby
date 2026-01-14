# frozen_string_literal: true

require "spec_helper"

RSpec.describe A2a::Client::Auth::InMemoryContextCredentialStore do
  let(:store) { described_class.new }
  let(:session_id) { "session-123" }
  let(:scheme_name) { "apikey" }
  let(:credential) { "secret-api-key" }

  describe "#set_credentials" do
    it "stores credentials for a session and scheme" do
      store.set_credentials(session_id, scheme_name, credential)

      context = A2a::Client::CallContext.new(state: { "sessionId" => session_id })
      retrieved = store.get_credentials(scheme_name, context)

      expect(retrieved).to eq(credential)
    end

    it "overwrites existing credentials" do
      store.set_credentials(session_id, scheme_name, credential)
      new_credential = "new-api-key"
      store.set_credentials(session_id, scheme_name, new_credential)

      context = A2a::Client::CallContext.new(state: { "sessionId" => session_id })
      retrieved = store.get_credentials(scheme_name, context)

      expect(retrieved).to eq(new_credential)
    end
  end

  describe "#get_credentials" do
    it "returns nil when context is nil" do
      store.set_credentials(session_id, scheme_name, credential)

      retrieved = store.get_credentials(scheme_name, nil)

      expect(retrieved).to be_nil
    end

    it "returns nil when context has no sessionId" do
      store.set_credentials(session_id, scheme_name, credential)

      context = A2a::Client::CallContext.new(state: {})
      retrieved = store.get_credentials(scheme_name, context)

      expect(retrieved).to be_nil
    end

    it "returns nil when session ID doesn't exist" do
      store.set_credentials(session_id, scheme_name, credential)

      context = A2a::Client::CallContext.new(state: { "sessionId" => "wrong-session" })
      retrieved = store.get_credentials(scheme_name, context)

      expect(retrieved).to be_nil
    end

    it "returns nil when scheme name doesn't exist" do
      store.set_credentials(session_id, scheme_name, credential)

      context = A2a::Client::CallContext.new(state: { "sessionId" => session_id })
      retrieved = store.get_credentials("unknown-scheme", context)

      expect(retrieved).to be_nil
    end

    it "handles symbol keys in state" do
      store.set_credentials(session_id, scheme_name, credential)

      context = A2a::Client::CallContext.new(state: { sessionId: session_id })
      retrieved = store.get_credentials(scheme_name, context)

      expect(retrieved).to eq(credential)
    end

    it "supports multiple schemes per session" do
      store.set_credentials(session_id, "apikey", "api-key-123")
      store.set_credentials(session_id, "oauth2", "oauth-token-456")

      context = A2a::Client::CallContext.new(state: { "sessionId" => session_id })

      expect(store.get_credentials("apikey", context)).to eq("api-key-123")
      expect(store.get_credentials("oauth2", context)).to eq("oauth-token-456")
    end
  end
end

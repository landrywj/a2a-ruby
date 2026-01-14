# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/a2a/auth"

RSpec.describe A2a::Auth::User do
  describe "abstract interface" do
    it "raises NotImplementedError for is_authenticated" do
      user = described_class.new

      expect { user.is_authenticated }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for user_name" do
      user = described_class.new

      expect { user.user_name }.to raise_error(NotImplementedError)
    end
  end
end

RSpec.describe A2a::Auth::UnauthenticatedUser do
  describe "#is_authenticated" do
    it "returns false" do
      user = described_class.new

      expect(user.is_authenticated).to be false
    end
  end

  describe "#user_name" do
    it "returns an empty string" do
      user = described_class.new

      expect(user.user_name).to eq("")
    end
  end
end

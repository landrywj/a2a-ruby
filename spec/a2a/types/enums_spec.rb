# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types do
  describe "Enums" do
    describe "TaskState" do
      it "defines all task state constants" do
        expect(A2a::Types::TaskState::SUBMITTED).to eq("submitted")
        expect(A2a::Types::TaskState::WORKING).to eq("working")
        expect(A2a::Types::TaskState::INPUT_REQUIRED).to eq("input-required")
        expect(A2a::Types::TaskState::COMPLETED).to eq("completed")
        expect(A2a::Types::TaskState::CANCELED).to eq("canceled")
        expect(A2a::Types::TaskState::FAILED).to eq("failed")
        expect(A2a::Types::TaskState::REJECTED).to eq("rejected")
        expect(A2a::Types::TaskState::AUTH_REQUIRED).to eq("auth-required")
        expect(A2a::Types::TaskState::UNKNOWN).to eq("unknown")
      end

      it "has all constants as strings" do
        constants = [
          A2a::Types::TaskState::SUBMITTED,
          A2a::Types::TaskState::WORKING,
          A2a::Types::TaskState::INPUT_REQUIRED,
          A2a::Types::TaskState::COMPLETED,
          A2a::Types::TaskState::CANCELED,
          A2a::Types::TaskState::FAILED,
          A2a::Types::TaskState::REJECTED,
          A2a::Types::TaskState::AUTH_REQUIRED,
          A2a::Types::TaskState::UNKNOWN
        ]
        constants.each do |constant|
          expect(constant).to be_a(String)
        end
      end
    end

    describe "Role" do
      it "defines user and agent roles" do
        expect(A2a::Types::Role::USER).to eq("user")
        expect(A2a::Types::Role::AGENT).to eq("agent")
      end

      it "has roles as strings" do
        expect(A2a::Types::Role::USER).to be_a(String)
        expect(A2a::Types::Role::AGENT).to be_a(String)
      end
    end

    describe "TransportProtocol" do
      it "defines all transport protocol constants" do
        expect(A2a::Types::TransportProtocol::JSONRPC).to eq("JSONRPC")
        expect(A2a::Types::TransportProtocol::GRPC).to eq("GRPC")
        expect(A2a::Types::TransportProtocol::HTTP_JSON).to eq("HTTP+JSON")
      end

      it "has all constants as strings" do
        [
          A2a::Types::TransportProtocol::JSONRPC,
          A2a::Types::TransportProtocol::GRPC,
          A2a::Types::TransportProtocol::HTTP_JSON
        ].each do |constant|
          expect(constant).to be_a(String)
        end
      end
    end

    describe "In" do
      it "defines API key location constants" do
        expect(A2a::Types::In::COOKIE).to eq("cookie")
        expect(A2a::Types::In::HEADER).to eq("header")
        expect(A2a::Types::In::QUERY).to eq("query")
      end

      it "has all constants as strings" do
        [
          A2a::Types::In::COOKIE,
          A2a::Types::In::HEADER,
          A2a::Types::In::QUERY
        ].each do |constant|
          expect(constant).to be_a(String)
        end
      end
    end
  end
end

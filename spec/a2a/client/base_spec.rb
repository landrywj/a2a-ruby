# frozen_string_literal: true

require "spec_helper"
require "a2a/client/base"

RSpec.describe A2a::Client::Base do
  let(:client) { described_class.new }

  describe "#initialize" do
    it "initializes with empty consumers and middleware by default" do
      expect(client.consumers).to eq([])
      expect(client.middleware).to eq([])
    end

    it "accepts consumers and middleware" do
      consumers = [proc { |_e, _c| }]
      middleware = [A2a::Client::CallInterceptor.new]
      client = described_class.new(consumers: consumers, middleware: middleware)
      expect(client.consumers).to eq(consumers)
      expect(client.middleware).to eq(middleware)
    end
  end

  describe "#add_event_consumer" do
    it "adds a consumer to the list" do
      consumer = proc { |_e, _c| }
      client.add_event_consumer(consumer)
      expect(client.consumers).to include(consumer)
    end
  end

  describe "#add_request_middleware" do
    it "adds middleware to the list" do
      middleware = A2a::Client::CallInterceptor.new
      client.add_request_middleware(middleware)
      expect(client.middleware).to include(middleware)
    end
  end

  describe "#consume" do
    it "calls all consumers with event and card" do
      called = []
      consumer1 = proc { |event, card| called << [:consumer1, event, card] }
      consumer2 = proc { |event, card| called << [:consumer2, event, card] }
      client = described_class.new(consumers: [consumer1, consumer2])

      event = "test_event"
      card = "test_card"
      client.consume(event, card)

      expect(called).to eq([[:consumer1, event, card], [:consumer2, event, card]])
    end

    it "does nothing if event is nil" do
      called = []
      consumer = proc { |_e, _c| called << :called }
      client = described_class.new(consumers: [consumer])
      client.consume(nil, "card")
      expect(called).to be_empty
    end
  end

  describe "abstract methods" do
    it "raises NotImplementedError for send_message" do
      expect { client.send_message(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_task" do
      expect { client.get_task(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for cancel_task" do
      expect { client.cancel_task(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for set_task_callback" do
      expect { client.set_task_callback(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_task_callback" do
      expect { client.get_task_callback(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for resubscribe" do
      expect { client.resubscribe(request: nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for get_card" do
      expect { client.get_card }.to raise_error(NotImplementedError)
    end
  end
end

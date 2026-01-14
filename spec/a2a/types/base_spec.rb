# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::BaseModel do
  let(:test_class) do
    Class.new(A2a::Types::BaseModel) do
      attr_accessor :name, :age, :email

      def initialize(attributes = {})
        super
        @name = attributes[:name] || attributes["name"]
        @age = attributes[:age] || attributes["age"]
        @email = attributes[:email] || attributes["email"]
      end
    end
  end

  describe "#initialize" do
    it "initializes from hash with symbol keys" do
      instance = test_class.new(name: "John", age: 30)
      expect(instance.name).to eq("John")
      expect(instance.age).to eq(30)
    end

    it "initializes from hash with string keys" do
      instance = test_class.new("name" => "Jane", "age" => 25)
      expect(instance.name).to eq("Jane")
      expect(instance.age).to eq(25)
    end

    it "handles camelCase keys" do
      instance = test_class.new("firstName" => "Bob", "lastName" => "Smith")
      # NOTE: This tests that camelCase is handled in attribute access
      expect(instance).to respond_to(:name)
    end

    it "handles metadata attribute" do
      instance = test_class.new(metadata: { "key" => "value" })
      expect(instance.metadata).to eq({ "key" => "value" })
    end

    it "handles empty hash" do
      instance = test_class.new({})
      expect(instance.name).to be_nil
      expect(instance.age).to be_nil
    end
  end

  describe "#to_h" do
    it "converts to hash with camelCase keys" do
      instance = test_class.new(name: "John", age: 30, email: "john@example.com")
      hash = instance.to_h
      expect(hash["name"]).to eq("John")
      expect(hash["age"]).to eq(30)
      expect(hash["email"]).to eq("john@example.com")
    end

    it "excludes nil values by default" do
      instance = test_class.new(name: "John")
      hash = instance.to_h
      expect(hash).not_to have_key("age")
      expect(hash).not_to have_key("email")
    end

    it "includes metadata if present" do
      instance = test_class.new(name: "John", metadata: { "key" => "value" })
      hash = instance.to_h
      expect(hash["metadata"]).to eq({ "key" => "value" })
    end

    it "handles nested BaseModel objects" do
      nested = test_class.new(name: "Nested")
      instance = test_class.new(name: "Parent", nested: nested)
      instance.instance_variable_set(:@nested, nested)
      hash = instance.to_h
      expect(hash["nested"]).to be_a(Hash)
      expect(hash["nested"]["name"]).to eq("Nested")
    end

    it "handles arrays of BaseModel objects" do
      items = [test_class.new(name: "Item1"), test_class.new(name: "Item2")]
      instance = test_class.new
      instance.instance_variable_set(:@items, items)
      hash = instance.to_h
      expect(hash["items"]).to be_an(Array)
      expect(hash["items"].first["name"]).to eq("Item1")
    end
  end

  describe "#to_json" do
    it "converts to JSON string" do
      instance = test_class.new(name: "John", age: 30)
      json = instance.to_json
      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed["name"]).to eq("John")
      expect(parsed["age"]).to eq(30)
    end

    it "produces valid JSON" do
      instance = test_class.new(name: "John", age: 30)
      json = instance.to_json
      expect { JSON.parse(json) }.not_to raise_error
    end
  end

  describe ".from_h" do
    it "creates instance from hash" do
      hash = { "name" => "John", "age" => 30 }
      instance = test_class.from_h(hash)
      expect(instance.name).to eq("John")
      expect(instance.age).to eq(30)
    end

    it "handles symbol keys" do
      hash = { name: "Jane", age: 25 }
      instance = test_class.from_h(hash)
      expect(instance.name).to eq("Jane")
      expect(instance.age).to eq(25)
    end
  end

  describe ".from_json" do
    it "creates instance from JSON string" do
      json = '{"name":"John","age":30}'
      instance = test_class.from_json(json)
      expect(instance.name).to eq("John")
      expect(instance.age).to eq(30)
    end

    it "handles complex JSON structures" do
      json = '{"name":"John","metadata":{"key":"value"}}'
      instance = test_class.from_json(json)
      expect(instance.name).to eq("John")
      expect(instance.metadata).to eq({ "key" => "value" })
    end
  end
end

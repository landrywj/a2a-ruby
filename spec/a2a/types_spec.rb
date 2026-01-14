# frozen_string_literal: true

require "spec_helper"
require "a2a/types"
require "a2a/utils"

# This file serves as a summary/entry point for all type specs
# Individual comprehensive specs are in separate files:
# - spec/a2a/types/base_spec.rb
# - spec/a2a/types/enums_spec.rb
# - spec/a2a/types/parts_spec.rb
# - spec/a2a/types/message_spec.rb
# - spec/a2a/types/task_spec.rb
# - spec/a2a/types/artifact_spec.rb
# - spec/a2a/types/agent_card_spec.rb
# - spec/a2a/utils_spec.rb

RSpec.describe A2a::Types do
  it "loads all type modules" do
    expect(A2a::Types::TaskState).to be_a(Module)
    expect(A2a::Types::Role).to be_a(Module)
    expect(A2a::Types::BaseModel).to be_a(Class)
    expect(A2a::Types::Message).to be_a(Class)
    expect(A2a::Types::Task).to be_a(Class)
  end
end

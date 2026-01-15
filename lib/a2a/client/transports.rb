# frozen_string_literal: true

require_relative "transports/base"
require_relative "transports/jsonrpc"
require_relative "transports/rest"

begin
  require_relative "transports/grpc"
rescue LoadError
  # gRPC transport is optional - only available if grpc gem is installed
  # and proto files are generated
end

# A2A Ruby SDK - Phased Implementation Plan

This document outlines a comprehensive, phased approach to implementing the A2A Protocol SDK in Ruby, based on the Python reference implementation.

## Overview

The A2A Protocol enables agent-to-agent communication through standardized JSON-RPC 2.0 messages. The Ruby SDK will provide both client and server implementations, supporting multiple transport protocols (JSON-RPC, REST, gRPC) and optional features.

## Architecture Principles

1. **Ruby Idioms First**: Use Ruby conventions (modules, blocks, metaprogramming) rather than direct Python translations
2. **Protocol Compliance**: Maintain full compatibility with the A2A Protocol specification
3. **Modular Design**: Support optional features through gem dependencies
4. **Use Existing Gems**: **CRITICAL** - Leverage well-established Ruby/Rails ecosystem gems instead of rewriting functionality. Prefer battle-tested libraries over custom implementations.
5. **Async Support**: Leverage Ruby's async capabilities (Fiber-based concurrency, async/await patterns)
6. **Type Safety**: Use RBS (Ruby Type Signatures) for type checking where beneficial

## Phase 1: Foundation & Core Types (Weeks 1-3)

### 1.1 Project Setup
- [ ] Configure gem structure (`a2a.gemspec`, `Gemfile`)
- [ ] Set up RSpec test framework
- [ ] Configure RBS type signatures directory
- [ ] Set up CI/CD pipeline
- [ ] Create base module structure (`lib/a2a/`)

### 1.2 Core Type System
**Goal**: Implement all protocol types as Ruby classes/modules

- [ ] **Base Model Infrastructure**
  - [ ] Create `A2A::BaseModel` (equivalent to `A2ABaseModel` in Python)
  - [ ] Use `active_support` for camelCase/snake_case conversion (`String#camelize`, `String#underscore`)
  - [ ] Set up JSON serialization/deserialization (using `json` standard library or `oj` gem)
  - [ ] Use `active_model` for validations instead of custom validation framework

- [ ] **Core Enums**
  - [ ] `A2A::In` (API key location: cookie, header, query)
  - [ ] `A2A::Role` (user, agent)
  - [ ] `A2A::TaskState` (submitted, working, input_required, completed, canceled, failed, rejected, auth_required, unknown)
  - [ ] `A2A::TransportProtocol` (JSONRPC, GRPC, HTTP+JSON)

- [ ] **Security Schemes**
  - [ ] `A2A::APIKeySecurityScheme`
  - [ ] `A2A::HTTPAuthSecurityScheme`
  - [ ] `A2A::OAuth2SecurityScheme` (with OAuth flows)
  - [ ] `A2A::OpenIdConnectSecurityScheme`
  - [ ] `A2A::MutualTLSSecurityScheme`
  - [ ] `A2A::SecurityScheme` (discriminated union)

- [ ] **Agent Card Types**
  - [ ] `A2A::AgentCardSignature`
  - [ ] `A2A::AgentExtension`
  - [ ] `A2A::AgentInterface`
  - [ ] `A2A::AgentProvider`
  - [ ] `A2A::AgentSkill`
  - [ ] `A2A::AgentCapabilities`
  - [ ] `A2A::AgentCard` (main card structure)

- [ ] **Message & Part Types**
  - [ ] `A2A::TextPart`
  - [ ] `A2A::FilePart` (with `FileWithBytes`, `FileWithUri`)
  - [ ] `A2A::DataPart`
  - [ ] `A2A::Part` (discriminated union)
  - [ ] `A2A::Message`

- [ ] **Task Types**
  - [ ] `A2A::TaskStatus`
  - [ ] `A2A::Task`
  - [ ] `A2A::Artifact`

- [ ] **Error Types**
  - [ ] `A2A::JSONRPCError`
  - [ ] `A2A::JSONParseError`
  - [ ] `A2A::InvalidRequestError`
  - [ ] `A2A::MethodNotFoundError`
  - [ ] `A2A::InvalidParamsError`
  - [ ] `A2A::InternalError`
  - [ ] `A2A::TaskNotFoundError`
  - [ ] `A2A::TaskNotCancelableError`
  - [ ] `A2A::PushNotificationNotSupportedError`
  - [ ] `A2A::UnsupportedOperationError`
  - [ ] `A2A::ContentTypeNotSupportedError`
  - [ ] `A2A::InvalidAgentResponseError`
  - [ ] `A2A::AuthenticatedExtendedCardNotConfiguredError`

- [ ] **JSON-RPC Types**
  - [ ] `A2A::JSONRPCMessage`
  - [ ] `A2A::JSONRPCRequest`
  - [ ] `A2A::JSONRPCSuccessResponse`
  - [ ] `A2A::JSONRPCErrorResponse`
  - [ ] `A2A::JSONRPCResponse` (discriminated union)

- [ ] **Request/Response Types**
  - [ ] `A2A::MessageSendParams`
  - [ ] `A2A::MessageSendConfiguration`
  - [ ] `A2A::TaskIdParams`
  - [ ] `A2A::TaskQueryParams`
  - [ ] `A2A::PushNotificationConfig`
  - [ ] `A2A::TaskPushNotificationConfig`
  - [ ] All method-specific request/response types

- [ ] **Event Types**
  - [ ] `A2A::TaskStatusUpdateEvent`
  - [ ] `A2A::TaskArtifactUpdateEvent`

### 1.3 Utilities & Constants
- [ ] `A2A::Constants` (well-known paths, default URLs)
- [ ] `A2A::Utils::Message` (message creation helpers)
- [ ] `A2A::Utils::Parts` (part extraction utilities)
- [ ] `A2A::Utils::Artifact` (artifact utilities)
- [ ] `A2A::Utils::Task` (task utilities)
- [ ] `A2A::Utils::Helpers` (general helpers)

### 1.4 Testing
- [ ] Unit tests for all type classes
- [ ] JSON serialization/deserialization tests
- [ ] Validation tests
- [ ] Test fixtures for sample AgentCards, Messages, Tasks

**Deliverables**: Complete type system with full test coverage, all types serializable to/from JSON matching A2A spec

---

## Phase 2: Client Foundation & Card Resolution (Weeks 4-5)

### 2.1 Client Base Infrastructure
- [ ] **Client Configuration**
  - [ ] `A2A::Client::Config` class
  - [ ] Support for streaming, polling, transport preferences
  - [ ] HTTP client configuration (use `faraday` or `httpx` equivalent)
  - [ ] Extension support configuration

- [ ] **Client Interface**
  - [ ] `A2A::Client::Base` abstract class
  - [ ] Define core client methods (send_message, get_task, cancel_task, etc.)
  - [ ] Event consumer pattern
  - [ ] Middleware/interceptor pattern

- [ ] **Card Resolution**
  - [ ] `A2A::Client::CardResolver` class
  - [ ] Fetch agent card from `/.well-known/agent-card.json`
  - [ ] Support for authenticated extended cards
  - [ ] Signature verification support
  - [ ] Caching mechanism

### 2.2 Client Factory
- [ ] `A2A::Client::Factory` class
  - [ ] Transport registry pattern
  - [ ] Automatic transport selection based on agent card
  - [ ] Support for custom transports
  - [ ] `Factory.connect` convenience method

### 2.3 Client Errors
- [ ] `A2A::Client::Error` base class
- [ ] `A2A::Client::HTTPError`
- [ ] `A2A::Client::JSONError`
- [ ] `A2A::Client::TimeoutError`
- [ ] `A2A::Client::InvalidStateError`

### 2.4 Testing
- [ ] Mock HTTP server for card resolution tests
- [ ] Factory tests
- [ ] Card resolver tests with various scenarios

**Deliverables**: Client infrastructure that can resolve agent cards and create clients, but not yet make requests

---

## Phase 3: JSON-RPC Transport (Weeks 6-8)

### 3.1 JSON-RPC Client Transport
- [ ] `A2A::Client::Transports::JSONRPC` class
  - [ ] Use `faraday` gem for HTTP client (Rails ecosystem standard)
  - [ ] Implement `ClientTransport` interface
  - [ ] `send_message` (non-streaming)
  - [ ] `send_message_streaming` (SSE support - use `faraday-sse` or similar)
  - [ ] `get_task`
  - [ ] `cancel_task`
  - [ ] `set_task_callback`, `get_task_callback`, `list_task_callback`, `delete_task_callback`
  - [ ] `resubscribe`
  - [ ] `get_card`
  - [ ] Error handling and retry logic (use `faraday-retry` middleware)
  - [ ] Request/response serialization

### 3.2 Base Client Implementation
- [ ] `A2A::Client::BaseClient` class
  - [ ] Integrate with transport
  - [ ] Implement `send_message` with streaming/polling logic
  - [ ] Task manager for aggregating streamed updates
  - [ ] Event consumer integration
  - [ ] Middleware chain execution

### 3.3 Client Helpers
- [ ] `A2A::Client::Helpers` module
  - [ ] `create_text_message` helper
  - [ ] Message construction utilities

### 3.4 Testing
- [ ] Mock JSON-RPC server
- [ ] Test all JSON-RPC methods
- [ ] Test streaming responses (SSE)
- [ ] Test error handling
- [ ] Test middleware chain
- [ ] Integration tests with real server (if available)

**Deliverables**: Fully functional JSON-RPC client that can communicate with A2A agents

---

## Phase 4: Authentication & Middleware (Weeks 9-10)

### 4.1 Authentication Infrastructure
- [ ] `A2A::Client::Auth::CredentialService` interface
- [ ] `A2A::Client::Auth::InMemoryCredentialStore`
- [ ] `A2A::Client::Auth::Interceptor` (auth middleware)
- [ ] Support for API keys, OAuth2, HTTP Auth, mTLS
- [ ] Token refresh logic for OAuth2

### 4.2 Middleware System
- [ ] `A2A::Client::Middleware::Context` class
- [ ] `A2A::Client::Middleware::Interceptor` interface
- [ ] Middleware chain execution
- [ ] Request/response transformation

### 4.3 Server-Side Auth
- [ ] `A2A::Auth::User` interface
- [ ] `A2A::Auth::UnauthenticatedUser`
- [ ] User extraction from request context

### 4.4 Testing
- [ ] Auth interceptor tests
- [ ] OAuth2 flow tests (mocked)
- [ ] Middleware chain tests
- [ ] Security scheme validation tests

**Deliverables**: Complete authentication system for both client and server

---

## Phase 5: REST Transport (Weeks 11-12)

### 5.1 REST Client Transport
- [ ] `A2A::Client::Transports::REST` class
  - [ ] Implement REST API mapping
  - [ ] HTTP method mapping (POST, GET, DELETE)
  - [ ] URL construction from agent card
  - [ ] Request/response handling

### 5.2 Testing
- [ ] REST transport tests
- [ ] Comparison tests with JSON-RPC transport
- [ ] Error handling tests

**Deliverables**: REST transport implementation

---

## Phase 6: Server Foundation (Weeks 13-16)

### 6.1 Server Core Infrastructure
- [ ] `A2A::Server::Context` class (server call context)
- [ ] `A2A::Server::RequestHandler` interface
- [ ] `A2A::Server::DefaultRequestHandler` base implementation
- [ ] Request routing/dispatching

### 6.2 Agent Execution
- [ ] `A2A::Server::AgentExecutor` interface
- [ ] `A2A::Server::RequestContext` class
- [ ] `A2A::Server::RequestContextBuilder` interface
- [ ] `A2A::Server::SimpleRequestContextBuilder`
- [ ] Context management

### 6.3 Event System
- [ ] `A2A::Server::Events::Event` base class
- [ ] `A2A::Server::Events::EventQueue` interface
- [ ] `A2A::Server::Events::InMemoryEventQueue`
- [ ] `A2A::Server::Events::EventConsumer`
- [ ] `A2A::Server::Events::QueueManager` interface
- [ ] `A2A::Server::Events::InMemoryQueueManager`

### 6.4 Request Handlers
- [ ] `A2A::Server::RequestHandlers::JSONRPCHandler`
  - [ ] JSON-RPC 2.0 request parsing
  - [ ] Method routing
  - [ ] Response formatting
  - [ ] Error handling
- [ ] `A2A::Server::RequestHandlers::RESTHandler`
  - [ ] REST endpoint mapping
  - [ ] Request/response conversion
- [ ] `A2A::Server::RequestHandlers::ResponseHelpers`
  - [ ] Response construction utilities
  - [ ] Error response formatting

### 6.5 Task Management
- [ ] Task storage interface (in-memory for now)
- [ ] Task lifecycle management
- [ ] Task state transitions
- [ ] Task history management

### 6.6 Testing
- [ ] Request handler tests
- [ ] Agent executor integration tests
- [ ] Event system tests
- [ ] End-to-end server tests

**Deliverables**: Functional server that can handle JSON-RPC and REST requests

---

## Phase 7: Server Streaming & Advanced Features (Weeks 17-19)

### 7.1 Server-Sent Events (SSE)
- [ ] SSE response handling
- [ ] Streaming message handler
- [ ] Event stream formatting
- [ ] Connection management

### 7.2 Push Notifications
- [ ] Push notification configuration storage
- [ ] Push notification delivery mechanism
- [ ] HTTP callback implementation
- [ ] Authentication for push notifications

### 7.3 Task Resubscription
- [ ] Resubscription handler
- [ ] Stream reconnection logic
- [ ] State recovery

### 7.4 Testing
- [ ] SSE streaming tests
- [ ] Push notification tests
- [ ] Resubscription tests

**Deliverables**: Full server with streaming and push notification support

---

## Phase 8: gRPC Support (Weeks 20-22)

### 8.1 gRPC Client Transport
- [ ] Generate Ruby gRPC stubs from protobuf definitions
- [ ] `A2A::Client::Transports::GRPC` class
  - [ ] gRPC channel management
  - [ ] Method mapping
  - [ ] Streaming support
  - [ ] Error handling

### 8.2 gRPC Server Handler
- [ ] `A2A::Server::RequestHandlers::GRPCHandler`
- [ ] gRPC service implementation
- [ ] Request/response conversion
- [ ] Streaming support

### 8.3 Testing
- [ ] gRPC client tests
- [ ] gRPC server tests
- [ ] Interoperability tests with Python SDK

**Deliverables**: Full gRPC support for both client and server

---

## Phase 9: HTTP Server Integration (Weeks 23-24)

### 9.1 HTTP Server Integration (Rails Ecosystem)
- [ ] Use `rack` as the base HTTP interface (Rails standard)
- [ ] Use `actionpack` / `action_dispatch` for routing and middleware (Rails ecosystem)
- [ ] `A2A::Server::Apps::REST::Application` class (Rack-compatible)
- [ ] REST endpoint registration using ActionDispatch routing
- [ ] Middleware integration using Rack middleware pattern
- [ ] SSE support (use `rack-sse` or similar gem)
- [ ] Consider `sinatra` or `grape` for lightweight API framework if full Rails is too heavy

### 9.2 JSON-RPC Server Application
- [ ] `A2A::Server::Apps::JSONRPC::Application` class
- [ ] JSON-RPC endpoint
- [ ] Request routing

### 9.3 Testing
- [ ] HTTP server integration tests
- [ ] End-to-end server tests

**Deliverables**: Ready-to-use HTTP server applications

---

## Phase 10: Extensions & Advanced Features (Weeks 25-27)

### 10.1 Extension System
- [ ] `A2A::Extensions::Common` utilities
- [ ] Extension registration mechanism
- [ ] Extension metadata handling
- [ ] Extension-specific request/response handling

### 10.2 Database Support (Optional)
- [ ] Use `activerecord` (Rails ORM) for database models - **preferred over Sequel/ROM**
- [ ] Database model interface using ActiveRecord patterns
- [ ] Task persistence models extending ActiveRecord::Base
- [ ] Database migrations using ActiveRecord migrations
- [ ] Support for PostgreSQL, MySQL, SQLite via ActiveRecord adapters
- [ ] Use `activerecord` gems: `pg`, `mysql2`, `sqlite3` for database drivers

### 10.3 Telemetry (Optional)
- [ ] OpenTelemetry integration
- [ ] Tracing support
- [ ] Metrics collection
- [ ] Logging framework integration

### 10.4 Signing & Encryption (Optional)
- [ ] JWT signing for agent cards
- [ ] Signature verification
- [ ] Encryption utilities

### 10.5 Testing
- [ ] Extension system tests
- [ ] Database integration tests
- [ ] Telemetry tests

**Deliverables**: Optional features as separate gem dependencies

---

## Phase 11: Polish & Documentation (Weeks 28-30)

### 11.1 Error Handling
- [ ] Comprehensive error handling
- [ ] Error message improvements
- [ ] Error recovery strategies

### 11.2 Performance Optimization
- [ ] Connection pooling
- [ ] Request batching (if applicable)
- [ ] Memory optimization
- [ ] Async performance tuning

### 11.3 Documentation
- [ ] README with examples
- [ ] API documentation (YARD)
- [ ] Usage guides
- [ ] Migration guide from Python SDK
- [ ] Architecture documentation

### 11.4 Examples & Samples
- [ ] Hello World example
- [ ] Client examples
- [ ] Server examples
- [ ] Streaming examples
- [ ] Authentication examples

### 11.5 Testing & Quality
- [ ] Increase test coverage to >90%
- [ ] Integration tests
- [ ] Performance tests
- [ ] Security audit
- [ ] Code review and refactoring

### 11.6 Release Preparation
- [ ] Version management
- [ ] CHANGELOG
- [ ] Release notes
- [ ] RubyGems publication
- [ ] Documentation site

**Deliverables**: Production-ready Ruby SDK with comprehensive documentation

---

## Technical Decisions & Considerations

### Ruby-Specific Adaptations

**IMPORTANT**: Prefer Rails ecosystem gems over alternatives when available.

1. **Async/Await**: Ruby 3.0+ has Fiber-based concurrency. Consider:
   - `async` gem for async/await patterns
   - Native `Fiber` for lightweight concurrency
   - `concurrent-ruby` for thread pools

2. **Type System**: 
   - Use RBS for type signatures
   - Consider `sorbet` for runtime type checking (optional, not Rails-specific)

3. **Validation**:
   - **Use `active_model`** for validations (Rails standard, well-tested)
   - Includes validators, callbacks, and attribute assignment
   - Avoid `dry-validation`/`dry-schema` unless there's a specific need

4. **HTTP Client**:
   - **Use `faraday`** (Rails ecosystem standard, most popular, flexible)
   - `faraday-retry` for retry logic
   - `faraday-sse` for Server-Sent Events support
   - Avoid `httpx` (not widely used in Rails ecosystem)

5. **JSON**:
   - `json` (standard library, sufficient for most cases)
   - `oj` (faster, optional optimization)

6. **HTTP Server Framework**:
   - **Use `rack`** as base interface (Rails standard)
   - **Use `actionpack` / `action_dispatch`** for routing and middleware (Rails ecosystem)
   - `sinatra` or `grape` for lightweight APIs (if full Rails stack not needed)
   - Avoid custom HTTP handling - use Rack middleware pattern

7. **Database ORM**:
   - **Use `activerecord`** (Rails standard, most widely used)
   - Database adapters: `pg` (PostgreSQL), `mysql2` (MySQL), `sqlite3` (SQLite)
   - Avoid `Sequel` or `ROM` unless there's a specific reason

8. **Utilities**:
   - **Use `active_support`** for:
     - String helpers (`camelize`, `underscore`, `pluralize`, etc.)
     - Time helpers (`Time.zone`, `in_time_zone`, etc.)
     - Inflections
     - Hash/Array extensions
     - Many other utilities
   - Avoid reimplementing these common utilities

9. **Testing**:
   - RSpec (standard)
   - `webmock` for HTTP mocking
   - `vcr` for HTTP recording
   - `rack-test` for testing Rack applications

10. **Authentication**:
    - Consider `warden` or `devise` patterns if complex auth needed
    - For OAuth: `omniauth` or `oauth2` gems
    - For JWT: `jwt` gem or `json-jwt`

11. **Logging**:
    - Use Ruby standard library `Logger` or `active_support` logger
    - Consider `lograge` for structured logging if needed

### Dependencies Structure

```ruby
# Core dependencies (always required)
spec.add_dependency "json", "~> 2.0"
spec.add_dependency "faraday", "~> 2.0"
spec.add_dependency "activesupport", "~> 7.0"  # Rails utilities
spec.add_dependency "activemodel", "~> 7.0"     # Validations and model behavior

# Optional dependencies (feature flags)
spec.add_development_dependency "rspec", "~> 3.12"
spec.add_development_dependency "yard", "~> 0.9"
spec.add_development_dependency "webmock", "~> 3.0"
spec.add_development_dependency "rack-test", "~> 2.0"

# Optional features (separate gems or feature flags)
# a2a-http-server:
#   - rack (base interface)
#   - actionpack / action_dispatch (routing, middleware)
#   - rack-sse (Server-Sent Events)
# a2a-grpc: grpc gem
# a2a-database:
#   - activerecord (ORM)
#   - pg, mysql2, or sqlite3 (database adapters)
# a2a-telemetry: opentelemetry-ruby
# a2a-encryption: jwt, openssl
# a2a-oauth: oauth2 or omniauth
```

### Module Structure

```
lib/a2a/
  ├── version.rb
  ├── base_model.rb
  ├── types/
  │   ├── agent_card.rb
  │   ├── message.rb
  │   ├── task.rb
  │   └── ...
  ├── client/
  │   ├── config.rb
  │   ├── base.rb
  │   ├── factory.rb
  │   ├── transports/
  │   │   ├── base.rb
  │   │   ├── jsonrpc.rb
  │   │   ├── rest.rb
  │   │   └── grpc.rb
  │   └── ...
  ├── server/
  │   ├── request_handler.rb
  │   ├── agent_executor.rb
  │   ├── request_handlers/
  │   │   ├── jsonrpc_handler.rb
  │   │   ├── rest_handler.rb
  │   │   └── grpc_handler.rb
  │   └── ...
  ├── utils/
  │   ├── message.rb
  │   ├── parts.rb
  │   └── ...
  └── ...
```

## Success Criteria

1. **Protocol Compliance**: 100% compatibility with A2A Protocol specification
2. **Interoperability**: Can communicate with Python SDK agents/clients
3. **Test Coverage**: >90% code coverage
4. **Performance**: Comparable to Python SDK for similar operations
5. **Documentation**: Complete API docs and usage examples
6. **Ruby Idioms**: Code follows Ruby style guide and best practices

## Risk Mitigation

1. **Async Complexity**: Start with synchronous implementation, add async later
2. **gRPC Complexity**: Use existing Ruby gRPC libraries, follow patterns
3. **Type System**: Start without strict types, add RBS gradually
4. **Performance**: Profile early, optimize bottlenecks
5. **Compatibility**: Continuous integration tests against Python SDK
6. **Gem Dependencies**: Prefer stable, well-maintained Rails ecosystem gems. Avoid experimental or niche libraries that may become unmaintained

## Timeline Summary

- **Phase 1-2**: Foundation (Weeks 1-5) - 5 weeks
- **Phase 3**: JSON-RPC Client (Weeks 6-8) - 3 weeks
- **Phase 4**: Auth & Middleware (Weeks 9-10) - 2 weeks
- **Phase 5**: REST Transport (Weeks 11-12) - 2 weeks
- **Phase 6**: Server Foundation (Weeks 13-16) - 4 weeks
- **Phase 7**: Server Streaming (Weeks 17-19) - 3 weeks
- **Phase 8**: gRPC (Weeks 20-22) - 3 weeks
- **Phase 9**: HTTP Server (Weeks 23-24) - 2 weeks
- **Phase 10**: Extensions (Weeks 25-27) - 3 weeks
- **Phase 11**: Polish (Weeks 28-30) - 3 weeks

**Total Estimated Time**: ~30 weeks (7.5 months) for full implementation

## Next Steps

1. Review and approve this plan
2. Set up project infrastructure (Phase 1.1)
3. Begin Phase 1.2 (Core Type System)
4. Establish regular review cycles
5. Create GitHub issues for each phase/task

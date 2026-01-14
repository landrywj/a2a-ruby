# A2A Ruby SDK

A Ruby implementation of the Agent-to-Agent (A2A) protocol. This SDK allows you to build agents that can communicate with each other using standardized JSON-RPC or REST interfaces.

## Features

- **Protocol Compliant**: Full implementation of the A2A Protocol specification.
- **Pluggable Transports**: Supports JSON-RPC 2.0 and REST (HTTP/JSON).
- **Security**: Built-in support for API Keys, OAuth2, OpenID Connect, and HTTP Bearer tokens.
- **Rails-Ready**: Optimized for deployment in **Rails API-only** applications.
- **Async & Background**: Integrated with `ActiveJob` for non-blocking agent interactions.
- **Persistent State**: Supports `ActiveRecord` for tracking task history across distributed workers.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'a2a'
```

And then execute:

```bash
bundle install
```

## Rails API-Only Deployment

This gem is designed to be the backbone of an agent-enabled Rails API.

### 1. Configuration

Create an initializer `config/initializers/a2a.rb`:

```ruby
A2a.configure do |config|
  config.streaming = true
  config.supported_transports = ['jsonrpc', 'http_json']
end
```

### 2. Async Agent Interaction

Instead of blocking your web workers, use `ActiveJob` to send messages to agents:

```ruby
# app/jobs/agent_task_job.rb
class AgentTaskJob < ApplicationJob
  queue_as :default

  def perform(agent_url, message_text)
    client = A2a::Client::Factory.connect(agent: agent_url)
    
    # Send message and process events asynchronously
    client.send_message(request: A2a::Client::Helpers.create_text_message(message_text)) do |task, update|
      # Update your ActiveRecord model with the task status
      AgentTask.find_by(task_id: task.id).update!(
        state: task.status.state,
        last_update: update&.to_h
      )
      
      # Optionally push updates to your frontend via ActionCable
      ActionCable.server.broadcast("agent_task_#{task.id}", update)
    end
  end
end
```

### 3. Handling Webhooks (Push Notifications)

Mount the A2A callback controller in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  post '/a2a/callbacks/:task_id', to: 'a2a_callbacks#handle'
end
```

And implement the controller to update your task state:

```ruby
# app/controllers/a2a_callbacks_controller.rb
class A2aCallbacksController < ApplicationController
  def handle
    event = A2a::Types::TaskStatusUpdateEvent.new(params.to_unsafe_h)
    task = AgentTask.find_by!(task_id: params[:task_id])
    
    # Update local state from the push notification
    task.update_from_event!(event)
    
    head :ok
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

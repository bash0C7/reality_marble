# Reality Marble Recipes: Common Patterns

Practical examples of using Reality Marble for common testing scenarios.

## 1. File System Operations

### Mock File Existence

```ruby
def test_file_not_found_handling
  RealityMarble.chant do
    expect(File, :exist?) { |path| false }
  end.activate do
    assert_raises(FileNotFoundError) { read_config_file }
  end
end
```

### Mock File Read

```ruby
def test_parse_config_from_mock_file
  config_content = "debug=true\nport=3000"

  RealityMarble.chant do
    expect(File, :read) { |path| config_content }
  end.activate do
    config = parse_config(path)
    assert_equal true, config[:debug]
    assert_equal 3000, config[:port]
  end
end
```

### Mock Directory Operations

```ruby
def test_backup_creates_directories
  RealityMarble.chant do
    expect(FileUtils, :mkdir_p) { |path| true }
  end.activate do
    backup_data('/backup/path')
  end

  # Verify directory was created
  mkdir_calls = marble.calls_for(FileUtils, :mkdir_p)
  assert mkdir_calls.any? { |call| call.args[0] == '/backup/path' }
end
```

---

## 2. HTTP Requests (Net::HTTP)

### Mock Successful Response

```ruby
def test_api_client_parses_response
  mock_response = '{"status":"ok","data":{"id":1}}'

  RealityMarble.chant do
    expect(Net::HTTP, :get) { |uri| mock_response }
  end.activate do
    result = fetch_user_data(1)
    assert_equal 1, result[:id]
  end
end
```

### Mock Multiple Calls with Sequence

```ruby
def test_retry_logic
  RealityMarble.chant do
    expect(API, :request)
      .with_any
      .returns(
        HTTPError.new("Timeout"),  # First call fails
        {"data" => [1, 2, 3]}       # Second call succeeds
      )
  end.activate do
    result = fetch_with_retry
    assert_equal [1, 2, 3], result
  end
end
```

### Mock Conditional Responses

```ruby
def test_api_handles_different_status_codes
  RealityMarble.chant do
    expect(API, :get) do |endpoint, status: 200|
      case status
      when 200
        {success: true, data: []}
      when 404
        raise NotFoundError
      when 500
        raise ServerError
      end
    end
  end.activate do
    assert_equal [], api.get('/users', status: 200)
    assert_raises(NotFoundError) { api.get('/missing', status: 404) }
    assert_raises(ServerError) { api.get('/broken', status: 500) }
  end
end
```

---

## 3. System Commands

### Mock Shell Commands

```ruby
def test_git_integration
  RealityMarble.chant do
    expect(Kernel, :system) do |cmd|
      case cmd
      when /git clone/
        puts "Cloned repository"
        true
      when /git push/
        puts "Pushed changes"
        true
      else
        false
      end
    end
  end.activate do
    git_workflow.clone_and_push
  end
end
```

### Mock Backtick Command Execution

```ruby
def test_command_output
  RealityMarble.chant do
    expect(Kernel, :`) do |cmd|
      case cmd
      when "git status"
        "On branch main\nnothing to commit"
      when "git log --oneline"
        "abc1234 Latest commit\ndef5678 Previous commit"
      end
    end
  end.activate do
    status = git_status
    log = git_log
    assert_includes(status, "main")
    assert_includes(log, "Latest commit")
  end
end
```

---

## 4. Database Operations

### Mock Database Query

```ruby
def test_user_service_returns_users
  users_data = [
    {id: 1, name: "Alice", email: "alice@example.com"},
    {id: 2, name: "Bob", email: "bob@example.com"}
  ]

  RealityMarble.chant do
    expect(Database, :query) { |sql| users_data if sql.include?("SELECT") }
  end.activate do
    users = user_service.all
    assert_equal 2, users.length
    assert_equal "Alice", users.first.name
  end
end
```

### Mock Transaction

```ruby
def test_transaction_rollback
  RealityMarble.chant do
    expect(Database, :transaction) do
      yield
    rescue RollbackError
      # Revert changes
    end
  end.activate do
    database.transaction do
      save_record(data)
      raise RollbackError if data.invalid?
    end
  end
end
```

---

## 5. Logger and Debugging

### Capture and Verify Logs

```ruby
def test_service_logs_important_events
  marble = RealityMarble.chant do
    expect(Logger, :info) { |msg| nil }
    expect(Logger, :warn) { |msg| nil }
  end.activate do
    service.process_order(order)
  end

  # Verify logs were called
  info_calls = marble.calls_for(Logger, :info)
  assert info_calls.any? { |call| call.args[0].include?("Order processed") }

  warn_calls = marble.calls_for(Logger, :warn)
  assert warn_calls.any? { |call| call.args[0].include?("Inventory low") }
end
```

### Mock Logger Output

```ruby
def test_error_logging
  RealityMarble.chant do
    expect(Logger, :error) { |msg| track_error(msg) }
  end.activate do
    error_handler.handle(exception)
  end
end
```

---

## 6. Testing Third-Party Libraries

### Mock Redis Operations

```ruby
def test_cache_with_redis
  RealityMarble.chant do
    expect(Redis, :get) { |key| @cache[key] }
    expect(Redis, :set) { |key, val| @cache[key] = val; "OK" }
  end.activate do
    cache = RedisCache.new
    cache.set("user:1", {id: 1, name: "Alice"})

    result = cache.get("user:1")
    assert_equal "Alice", result[:name]
  end
end
```

### Mock AWS S3

```ruby
def test_file_upload_to_s3
  RealityMarble.chant do
    expect(S3Client, :put_object) do |bucket:, key:, body:|
      @uploaded_files[key] = body
      {etag: "abc123"}
    end
  end.activate do
    s3.upload("my-bucket", "document.pdf", file_content)
  end

  assert @uploaded_files.key?("document.pdf")
end
```

---

## 7. Exception Handling

### Test Error Recovery

```ruby
def test_fallback_on_api_failure
  RealityMarble.chant do
    expect(API, :fetch_data) do |id|
      raise APIError.new("Service unavailable")
    end
  end.activate do
    result = fetch_with_fallback(123)
    assert_equal FALLBACK_DATA, result
  end
end
```

### Test Exception Propagation

```ruby
def test_invalid_input_raises
  RealityMarble.chant do
    expect(Validator, :validate) do |data|
      raise ValidationError.new("Invalid email") unless data[:email].valid?
      true
    end
  end.activate do
    assert_raises(ValidationError) do
      validator.validate({email: "not-an-email"})
    end
  end
end
```

---

## 8. Complex Workflows

### Multi-Step Workflow with Mocks

```ruby
def test_payment_workflow
  marble = RealityMarble.chant do
    expect(PaymentGateway, :charge) { |amount| {id: "txn_123", amount: amount} }
    expect(Inventory, :reserve) { |item, qty| true }
    expect(EmailService, :send) { |to, subject| nil }
  end.activate do
    order = Order.new(items: [item1, item2], total: 100)
    process_order(order)
  end

  # Verify workflow steps
  charge_calls = marble.calls_for(PaymentGateway, :charge)
  assert_equal 1, charge_calls.length
  assert_equal 100, charge_calls[0].args[0]

  reserve_calls = marble.calls_for(Inventory, :reserve)
  assert_equal 2, reserve_calls.length  # Called for each item
end
```

### Nested Marble Workflow

```ruby
def test_outer_and_inner_mocks
  outer = RealityMarble.chant do
    expect(UserService, :find) { |id| User.new(id: id) }
  end

  inner = RealityMarble.chant do
    expect(UserService, :find) { |id| MockUser.new(id: id) }
  end

  outer.activate do
    outer_user = UserService.find(1)
    assert_instance_of User, outer_user

    inner.activate do
      inner_user = UserService.find(1)
      assert_instance_of MockUser, inner_user
    end

    back_to_outer = UserService.find(1)
    assert_instance_of User, back_to_outer
  end
end
```

---

## 9. Quick Inline Mocking

### Use .mock() Helper

```ruby
# Simple one-liner mocks without chant/activate
class UserServiceTest < Test::Unit::TestCase
  def test_user_lookup
    RealityMarble.mock(Database, :query) { |sql| [{id: 1, name: "Alice"}] }

    user = UserService.find(1)
    assert_equal "Alice", user.name
  end

  def teardown
    RealityMarble::Context.reset_current
  end
end
```

---

## 10. Testing Edge Cases

### Mock Partial Failure

```ruby
def test_graceful_degradation
  RealityMarble.chant do
    expect(PrimaryAPI, :fetch) { raise TimeoutError }
    expect(SecondaryAPI, :fetch) { {data: "from-secondary"} }
  end.activate do
    result = fetch_with_fallback
    assert_equal "from-secondary", result[:data]
  end
end
```

### Mock Resource Exhaustion

```ruby
def test_retry_on_resource_limit
  RealityMarble.chant do
    expect(ResourcePool, :acquire)
      .with_any
      .returns(
        ResourceLimitError.new("All threads in use"),
        ResourceLimitError.new("All threads in use"),
        Resource.new(id: 1)  # Third call succeeds
      )
  end.activate do
    resource = pool.acquire_with_retry
    assert_equal 1, resource.id
  end
end
```

---

## Best Practices

### ✅ DO

- Use clear, descriptive marble variable names
- Group related expectations in a single chant block
- Verify call history to ensure mocks were actually called
- Use blocks for conditional logic
- Reset context in teardown

```ruby
def test_example
  marble = RealityMarble.chant do
    expect(Service, :method) { "response" }
  end.activate do
    result = call_service
  end

  calls = marble.calls_for(Service, :method)
  assert_equal 1, calls.length
end

def teardown
  RealityMarble::Context.reset_current
end
```

### ❌ DON'T

- Mock methods that don't exist without understanding implications
- Leave mocks active outside of activate block (use reset_current)
- Create deeply nested marbles for complex scenarios (refactor tests instead)
- Mock internal implementation details (mock external dependencies only)

```ruby
# Bad: Mocking internal detail
RealityMarble.chant do
  expect(MyService, :private_helper) { ... }  # ❌ Internal method
end

# Good: Mock external dependency
RealityMarble.chant do
  expect(ExternalAPI, :fetch) { ... }  # ✅ External boundary
end
```

---

## Troubleshooting

### Mock Not Being Called

```ruby
# Check if expectations match actual arguments
marble = RealityMarble.chant do
  expect(Foo, :bar).with(1, 2)  # Expects exact args (1, 2)
end.activate do
  Foo.bar(1, 2, 3)  # Actually called with (1, 2, 3) - NO MATCH
end

# Use .with_any instead
expect(Foo, :bar).with_any
```

### Original Method Not Restored

```ruby
# Ensure Context.reset_current is called in teardown
def teardown
  RealityMarble::Context.reset_current  # Important!
end
```

---

## See Also

- [CONCEPT.md](./CONCEPT.md) - Philosophical background
- [API.md](./API.md) - Complete API reference
- [../README.md](../README.md) - Quick start guide

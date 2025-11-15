# Reality Marble Recipes: Common Patterns

Practical examples of using Reality Marble for common testing scenarios.

All recipes use native Ruby syntax with `define_method`/`define_singleton_method`.

---

## 1. File System Operations

### Mock File Existence

```ruby
def test_file_not_found_handling
  RealityMarble.chant do
    File.define_singleton_method(:exist?) do |path|
      false  # Simulate file not found
    end
  end.activate do
    assert_raises(FileNotFoundError) { read_config_file }
  end
end
```

### Mock File Read with Content

```ruby
def test_parse_config_from_mock_file
  config_content = "debug=true\nport=3000"

  RealityMarble.chant do
    File.define_singleton_method(:read) do |path|
      config_content
    end
  end.activate do
    config = parse_config(path)
    assert_equal true, config[:debug]
    assert_equal 3000, config[:port]
  end
end
```

### Mock Directory Operations and Track Calls

```ruby
def test_backup_creates_directories
  paths_created = []

  marble = RealityMarble.chant(capture: { paths: paths_created }) do |cap|
    FileUtils.define_singleton_method(:mkdir_p) do |path|
      cap[:paths] << path
      true
    end
  end.activate do
    backup_data('/backup/path')
    backup_data('/backup/logs')
  end

  # Verify directories were created
  assert_equal 2, paths_created.length
  assert paths_created.include?('/backup/path')
  assert paths_created.include?('/backup/logs')
end
```

### Mock Conditional File Operations

```ruby
def test_file_exists_conditionally
  RealityMarble.chant do
    File.define_singleton_method(:exist?) do |path|
      path.start_with?('/cache')
    end

    File.define_singleton_method(:read) do |path|
      if path.start_with?('/cache')
        "cached content"
      else
        raise FileNotFoundError
      end
    end
  end.activate do
    assert File.exist?('/cache/data.txt')
    refute File.exist?('/tmp/file.txt')
    assert_equal "cached content", File.read('/cache/data.txt')
  end
end
```

---

## 2. HTTP Requests

### Mock Successful API Response

```ruby
def test_api_client_parses_response
  mock_response = '{"status":"ok","data":{"id":1,"name":"Alice"}}'

  RealityMarble.chant do
    Net::HTTP.define_singleton_method(:get) do |uri|
      mock_response
    end
  end.activate do
    result = fetch_user_data(1)
    assert_equal 1, result[:id]
    assert_equal "Alice", result[:name]
  end
end
```

### Mock Different Response Conditions

```ruby
def test_api_handles_different_status_codes
  RealityMarble.chant do
    MyAPI.define_singleton_method(:get) do |endpoint, status: 200|
      case status
      when 200
        { success: true, data: [] }
      when 404
        raise NotFoundError, "Endpoint not found"
      when 500
        raise ServerError, "Internal server error"
      end
    end
  end.activate do
    assert_equal [], MyAPI.get('/users', status: 200)
    assert_raises(NotFoundError) { MyAPI.get('/missing', status: 404) }
    assert_raises(ServerError) { MyAPI.get('/broken', status: 500) }
  end
end
```

### Track API Calls and Request Parameters

```ruby
def test_api_client_sends_correct_headers
  requests = []

  marble = RealityMarble.chant(capture: { reqs: requests }) do |cap|
    Net::HTTP.define_singleton_method(:get) do |uri, headers = {}|
      cap[:reqs] << { uri: uri, headers: headers }
      '{"data": "response"}'
    end
  end.activate do
    MyAPIClient.fetch('/api/users', { 'Authorization' => 'Bearer token123' })
    MyAPIClient.fetch('/api/posts', { 'Authorization' => 'Bearer token456' })
  end

  # Verify requests
  calls = marble.calls_for(Net::HTTP, :get)
  assert_equal 2, calls.length
  assert_equal '/api/users', requests[0][:uri]
  assert_equal 'Bearer token123', requests[0][:headers]['Authorization']
end
```

---

## 3. System Commands

### Mock Shell Commands

```ruby
def test_git_integration
  RealityMarble.chant do
    Kernel.define_method(:system) do |cmd|
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
    assert git_workflow.clone_and_push
  end
end
```

### Track System Command Execution

```ruby
def test_deployment_executes_correct_commands
  executed_commands = []

  RealityMarble.chant(capture: { cmds: executed_commands }) do |cap|
    Kernel.define_method(:system) do |cmd|
      cap[:cmds] << cmd
      true
    end
  end.activate do
    deployer.deploy_to_production
  end

  assert executed_commands.any? { |cmd| cmd.include?('docker build') }
  assert executed_commands.any? { |cmd| cmd.include?('docker push') }
  assert executed_commands.any? { |cmd| cmd.include?('kubectl apply') }
end
```

### Mock Backtick Command Output

```ruby
def test_parse_git_log
  RealityMarble.chant do
    Kernel.define_method(:`).define_method(:`).define_singleton_method(:`) do |cmd|
      case cmd
      when "git log --oneline"
        "abc1234 Latest commit\ndef5678 Previous commit\n"
      when "git status"
        "On branch main\nnothing to commit\n"
      else
        ""
      end
    end
  end.activate do
    log = `git log --oneline`
    assert log.include?("abc1234")
  end
end
```

---

## 4. Database Operations

### Mock Database Queries

```ruby
def test_user_repository_returns_user
  mock_user = User.new(id: 1, name: "Alice", email: "alice@example.com")

  RealityMarble.chant do
    UserRepository.define_singleton_method(:find) do |user_id|
      user_id == 1 ? mock_user : nil
    end
  end.activate do
    user = UserRepository.find(1)
    assert_equal "Alice", user.name
    assert_nil UserRepository.find(999)
  end
end
```

### Mock Database Transactions

```ruby
def test_transaction_rollback_on_error
  transaction_state = { committed: false, rolled_back: false }

  RealityMarble.chant(capture: { state: transaction_state }) do |cap|
    Database.define_singleton_method(:transaction) do |&block|
      begin
        block.call
        cap[:state][:committed] = true
      rescue StandardError
        cap[:state][:rolled_back] = true
        raise
      end
    end
  end.activate do
    assert_raises(ValidationError) do
      Database.transaction do
        # Business logic that fails
        raise ValidationError, "Invalid data"
      end
    end
  end

  assert transaction_state[:rolled_back]
  refute transaction_state[:committed]
end
```

### Track Database Calls

```ruby
def test_user_service_minimizes_database_hits
  db_calls = []

  marble = RealityMarble.chant(capture: { calls: db_calls }) do |cap|
    User.define_singleton_method(:find_by) do |attrs|
      cap[:calls] << { method: :find_by, attrs: attrs }
      User.new(id: 1, name: "Alice")
    end
  end.activate do
    service = UserService.new
    user1 = service.get_user(1)
    user2 = service.get_user(1)  # Should use cache, not call DB again
  end

  # Verify calls were minimized
  calls = marble.calls_for(User, :find_by)
  assert_equal 1, calls.length  # Called only once due to caching
end
```

---

## 5. Logger and Observability

### Mock Logger and Track Messages

```ruby
def test_error_handler_logs_exceptions
  log_messages = []

  RealityMarble.chant(capture: { logs: log_messages }) do |cap|
    Logger.define_singleton_method(:error) do |message|
      cap[:logs] << { level: :error, message: message }
    end

    Logger.define_singleton_method(:info) do |message|
      cap[:logs] << { level: :info, message: message }
    end
  end.activate do
    error_handler.handle_exception(StandardError.new("Oops!"))
  end

  error_logs = log_messages.select { |log| log[:level] == :error }
  assert error_logs.any? { |log| log[:message].include?("Oops!") }
end
```

### Mock Logger Formatters

```ruby
def test_logger_formats_timestamps
  formatted_lines = []

  RealityMarble.chant(capture: { lines: formatted_lines }) do |cap|
    Logger.define_singleton_method(:format) do |level, message, timestamp|
      formatted = "[#{timestamp}] #{level}: #{message}"
      cap[:lines] << formatted
      formatted
    end
  end.activate do
    logger = Logger.new
    logger.log(:info, "User logged in", Time.now)
  end

  assert formatted_lines[0].include?("[")
  assert formatted_lines[0].include?("]")
end
```

---

## 6. Exception Handling

### Mock Methods That Raise Exceptions

```ruby
def test_error_recovery
  RealityMarble.chant do
    API.define_singleton_method(:fetch) do |url|
      raise TimeoutError, "Connection timeout"
    end
  end.activate do
    assert_raises(TimeoutError) do
      APIClient.fetch_data('/endpoint')
    end
  end
end
```

### Mock Conditional Exceptions

```ruby
def test_validation_error_handling
  RealityMarble.chant do
    Model.define_method(:save) do
      if @attributes[:email].nil?
        raise ValidationError, "Email is required"
      end
      true
    end
  end.activate do
    model = Model.new
    assert_raises(ValidationError) do
      model.save
    end

    model.attributes = { email: "user@example.com" }
    assert model.save
  end
end
```

### Track Exception Handling

```ruby
def test_exception_handler_tracks_errors
  error_log = []

  RealityMarble.chant(capture: { errors: error_log }) do |cap|
    ErrorHandler.define_singleton_method(:handle) do |error|
      cap[:errors] << { class: error.class, message: error.message }
    end
  end.activate do
    handler = ErrorHandler.new
    handler.handle(ArgumentError.new("Invalid argument"))
    handler.handle(TimeoutError.new("Request timeout"))
  end

  assert_equal 2, error_log.length
  assert_equal ArgumentError, error_log[0][:class]
  assert_equal TimeoutError, error_log[1][:class]
end
```

---

## 7. State and Side Effects

### Mock Methods with Side Effects

```ruby
def test_user_creation_sends_email
  emails_sent = []

  RealityMarble.chant(capture: { emails: emails_sent }) do |cap|
    EmailService.define_singleton_method(:send_welcome) do |email|
      cap[:emails] << email
      true
    end
  end.activate do
    UserService.create_user("alice@example.com")
  end

  assert_equal ["alice@example.com"], emails_sent
end
```

### Mock Methods with Mutable State

```ruby
def test_counter_increments
  counter_state = { value: 0 }

  RealityMarble.chant(capture: { counter: counter_state }) do |cap|
    Counter.define_singleton_method(:increment) do
      cap[:counter][:value] += 1
    end

    Counter.define_singleton_method(:current) do
      cap[:counter][:value]
    end
  end.activate do
    Counter.increment
    Counter.increment
    Counter.increment
    assert_equal 3, Counter.current
  end
end
```

---

## 8. Nested Mocks

### Multiple Methods in Same Class

```ruby
def test_file_operations_combined
  RealityMarble.chant do
    File.define_singleton_method(:exist?) do |path|
      path == '/data/file.txt'
    end

    File.define_singleton_method(:read) do |path|
      "file content"
    end

    File.define_singleton_method(:write) do |path, content|
      true
    end
  end.activate do
    assert File.exist?('/data/file.txt')
    content = File.read('/data/file.txt')
    File.write('/data/file.txt', content + " modified")
  end
end
```

### Methods in Different Classes

```ruby
def test_integration_across_classes
  RealityMarble.chant do
    Logger.define_singleton_method(:info) do |msg|
      puts "[INFO] #{msg}"
    end

    Database.define_singleton_method(:query) do |sql|
      [{ id: 1, name: "Result" }]
    end

    EmailService.define_singleton_method(:send) do |email|
      true
    end
  end.activate do
    service = MyService.new
    service.process_data
  end
end
```

---

## 9. Before/After Verification

### Verify Method Was Called

```ruby
def test_payment_processor_charges_card
  RealityMarble.chant do
    PaymentGateway.define_singleton_method(:charge) do |amount, card|
      { success: true, transaction_id: "tx_123" }
    end
  end.activate do
    processor = PaymentProcessor.new
    result = processor.charge_card(100, "4111111111111111")
    assert result[:success]
  end

  # Verify charge was called
  calls = marble.calls_for(PaymentGateway, :charge)
  assert_equal 1, calls.length
  assert_equal 100, calls[0].args[0]
end
```

### Capture and Verify Multiple Arguments

```ruby
def test_auth_service_validates_credentials
  auth_attempts = []

  marble = RealityMarble.chant(capture: { attempts: auth_attempts }) do |cap|
    AuthService.define_singleton_method(:validate) do |username, password|
      cap[:attempts] << { user: username, pass: password }
      username == 'admin' && password == 'secret123'
    end
  end.activate do
    assert AuthService.validate('admin', 'secret123')
    refute AuthService.validate('user', 'wrong')
  end

  assert_equal 2, auth_attempts.length
  assert_equal 'admin', auth_attempts[0][:user]
  assert_equal 'user', auth_attempts[1][:user]
end
```

---

## 10. Advanced Patterns

### Method Chain Mocking

```ruby
def test_active_record_chain_mocking
  RealityMarble.chant do
    User.define_singleton_method(:where) do |conditions|
      UserScope.new(conditions)
    end

    UserScope.define_method(:limit) do |count|
      self
    end

    UserScope.define_method(:all) do
      [User.new(id: 1, name: "Alice")]
    end
  end.activate do
    results = User.where(active: true).limit(10).all
    assert_equal 1, results.length
  end
end
```

### Recursive Method Mocking

```ruby
def test_tree_traversal
  RealityMarble.chant do
    TreeNode.define_method(:children) do
      @children ||= []
    end

    TreeNode.define_method(:add_child) do |node|
      @children ||= []
      @children << node
    end
  end.activate do
    root = TreeNode.new('root')
    child1 = TreeNode.new('child1')
    child2 = TreeNode.new('child2')

    root.add_child(child1)
    root.add_child(child2)

    assert_equal 2, root.children.length
  end
end
```

---

## Best Practices

### ✅ DO: Use Native Syntax

```ruby
# Good
RealityMarble.chant do
  MyClass.define_singleton_method(:method) do |arg|
    arg * 2
  end
end.activate { ... }
```

### ✅ DO: Capture State When You Need Verification

```ruby
# Good - captures state for verification
state = { called: false }
RealityMarble.chant(capture: { state: state }) do |cap|
  MyClass.define_singleton_method(:do_something) do
    cap[:state][:called] = true
  end
end.activate { MyClass.do_something }
assert state[:called]
```

### ✅ DO: Use calls_for() for Call History

```ruby
# Good - uses call history
marble = RealityMarble.chant do
  MyClass.define_singleton_method(:save) { true }
end.activate { MyClass.save; MyClass.save }

calls = marble.calls_for(MyClass, :save)
assert_equal 2, calls.length
```

### ❌ DON'T: Forget to Clean Up

```ruby
# Bad - may leak mocks
RealityMarble.chant { ... }.activate { ... }
# (This is fine - cleanup happens automatically)

# But in multi-threaded tests:
def teardown
  RealityMarble::Context.reset_current  # Clean up thread-local state
end
```

### ❌ DON'T: Rely on Global Mocking

```ruby
# Bad - mocks leak between tests
RealityMarble.chant { MyClass.define_singleton_method(:foo) { 1 } }
# Mock is gone! Mocks are only active during .activate block

# Good - use .activate to keep mocks active
RealityMarble.chant { ... }.activate { ... }
```

---

## See Also

- [CONCEPT.md](./CONCEPT.md) - Philosophical background and design patterns
- [API.md](./API.md) - Complete API reference
- [../README.md](../README.md) - Quick start guide

#!/usr/bin/env ruby
# Reality Marble: File Operations Example
# Demonstrates mocking File and FileUtils for safe file system testing.

require_relative '../lib/reality_marble'

puts "=" * 60
puts "Reality Marble: File Operations Example"
puts "=" * 60

# Example 1: Mock file existence check
puts "\n1. Mock File.exist? with conditional logic:"
puts "-" * 40

RealityMarble.chant do
  expect(File, :exist?) do |path|
    ['/tmp/config.yml', '/etc/app.conf'].include?(path)
  end
end.activate do
  config_paths = ['/tmp/config.yml', '/etc/app.conf', '/nonexistent/path']

  config_paths.each do |path|
    exists = File.exist?(path)
    puts "  File.exist?(#{path.inspect}) => #{exists}"
  end

  puts "  ✓ Different responses based on path argument"
end

# Example 2: Mock file read with different content per file
puts "\n2. Mock File.read with conditional content:"
puts "-" * 40

file_contents = {
  '/config/app.yml' => "app_name: MyApp\nversion: 1.0",
  '/config/db.yml' => "database: postgres\nport: 5432"
}

RealityMarble.chant do
  expect(File, :read) do |path|
    file_contents[path] || "File not found: #{path}"
  end
end.activate do
  app_config = File.read('/config/app.yml')
  db_config = File.read('/config/db.yml')

  puts "  app.yml content:"
  puts "    #{app_config.inspect}"
  puts "  db.yml content:"
  puts "    #{db_config.inspect}"

  puts "  ✓ Different files return different content"
end

# Example 3: Mock FileUtils operations and track calls
puts "\n3. Track FileUtils operations:"
puts "-" * 40

marble = RealityMarble.chant do
  expect(FileUtils, :mkdir_p) { |path| puts "    [Mocked] Created directory: #{path}" }
  expect(FileUtils, :cp_r) { |src, dest| puts "    [Mocked] Copied #{src} to #{dest}" }
  expect(FileUtils, :rm_rf) { |path| puts "    [Mocked] Removed: #{path}" }
end

marble.activate do
  puts "  Performing file operations..."

  FileUtils.mkdir_p('/backup/data')
  FileUtils.mkdir_p('/backup/logs')
  FileUtils.cp_r('/var/data', '/backup/data')
  FileUtils.rm_rf('/tmp/old_backups')
end

mkdir_calls = marble.calls_for(FileUtils, :mkdir_p)
puts "  Recorded operations:"
puts "    - mkdir_p called #{mkdir_calls.length} times"
mkdir_calls.each { |call| puts "      * #{call.args[0].inspect}" }

cp_calls = marble.calls_for(FileUtils, :cp_r)
puts "    - cp_r called #{cp_calls.length} times"
cp_calls.each { |call| puts "      * #{call.args[0].inspect} -> #{call.args[1].inspect}" }

puts "  ✓ Multiple operations tracked in call history"

# Example 4: Mock file operations that raise exceptions
puts "\n4. Mock permission errors:"
puts "-" * 40

RealityMarble.chant do
  expect(File, :read) do |path|
    raise Errno::EACCES, "Permission denied: #{path}" if path.start_with?('/root/')
    "File content"
  end
end.activate do
  begin
    File.read('/etc/passwd')
    puts "  Successfully read /etc/passwd (mocked)"
  rescue Errno::EACCES => e
    puts "  ✗ Unexpected permission error: #{e.message}"
  end

  begin
    File.read('/root/secret.txt')
    puts "  ✗ Should have raised permission error"
  rescue Errno::EACCES => e
    puts "  ✓ Permission error raised as expected: #{e.message}"
  end
end

# Example 5: Real-world scenario - Safe backup testing
puts "\n5. Real-world: Safe backup scenario testing:"
puts "-" * 40

# Simulate a backup service without touching actual files
marble = RealityMarble.chant do
  expect(Dir, :glob) { |pattern| simulate_glob(pattern) }
  expect(File, :size) { |path| rand(1000..10000) }
  expect(FileUtils, :mkdir_p) { |path| puts "    [Mocked] Created backup directory: #{path}" }
  expect(FileUtils, :cp) { |src, dest| puts "    [Mocked] Backed up: #{src} -> #{dest}" }
end

marble.activate do
  puts "  Running backup service..."

  # Create backup directory
  FileUtils.mkdir_p('/mnt/backups/2024-01-15')

  # Find all app files
  app_files = Dir.glob('/app/**/*.rb')
  puts "  Found #{app_files.length} Ruby files"

  # Backup each file
  app_files.each do |file|
    size = File.size(file)
    FileUtils.cp(file, "/mnt/backups/2024-01-15/#{File.basename(file)}")
  end
end

puts "  ✓ Backup service tested without touching real files"

# Helper function for simulating Dir.glob
def simulate_glob(pattern)
  case pattern
  when '/app/**/*.rb'
    ['/app/main.rb', '/app/config.rb', '/app/lib/utils.rb']
  when '/app/**/*'
    Dir.glob('/app/**/*')
  else
    []
  end
end

# Cleanup
RealityMarble::Context.reset_current

puts "\n" + "=" * 60
puts "File operations examples completed!"
puts "=" * 60

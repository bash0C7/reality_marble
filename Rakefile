require "bundler/gem_tasks"
require "rake/testtask"
require "English"

# ============================================================================
# MAIN TEST TASK
# ============================================================================
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].sort
  # Ruby warning suppress: method redefinition warnings in test mocks
  t.ruby_opts = ["-W1"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new do |task|
  # CI用：チェックのみ（自動修正なし）
  task.options = []
end

# 開発者向け：RuboCop自動修正タスク
desc "Run RuboCop with auto-correction"
task "rubocop:fix" do
  system("bundle exec rubocop --auto-correct-all")
  exit $CHILD_STATUS.exitstatus unless $CHILD_STATUS.success?
end

# ============================================================================
# TYPE SYSTEM TASKS (Priority 1: rbs-inline + Steep)
# ============================================================================

namespace :rbs do
  desc "Generate RBS files from rbs-inline annotations"
  task :generate do
    puts "📝 Generating .rbs files from rbs-inline annotations..."
    sh "bundle exec rbs-inline --output sig lib"
    puts "✓ .rbs files generated in sig/"
  end
end

desc "Run type check with Steep"
task :steep do
  puts "🔍 Running Steep type checker..."
  sh "bundle exec steep check"
  puts "✓ Type check passed!"
end

# カバレッジ検証タスク（test実行後にcoverage.xmlが生成されていることを確認）
desc "Validate SimpleCov coverage report was generated"
task :coverage_validation do
  coverage_file = File.join(Dir.pwd, "coverage", "coverage.xml")
  abort "ERROR: SimpleCov coverage report not found at #{coverage_file}" unless File.exist?(coverage_file)
  puts "✓ SimpleCov coverage report validated: #{coverage_file}"
end

# SimpleCov をリセット（test の前に実行）
desc "Reset coverage directory before test runs"
task :reset_coverage do
  coverage_dir = File.join(Dir.pwd, "coverage")
  FileUtils.rm_rf(coverage_dir)
  puts "✓ Coverage directory reset"
end

# ============================================================================
# PUBLIC TASKS: CI and Development
# ============================================================================

# CI task: All tests + RuboCop check + coverage validation (NO auto-correction)
desc "Run CI: all tests, RuboCop validation, and coverage validation"
task ci: %i[reset_coverage test rubocop coverage_validation] do
  puts "\n✓ CI passed! All tests + RuboCop + coverage validated."
end

# Development task: RuboCop auto-fix, run all tests, validate coverage
desc "Development: RuboCop auto-fix, run all tests, validate coverage"
task dev: ["rubocop:fix", :reset_coverage, :test, :coverage_validation] do
  puts "\n✓ Development checks passed! RuboCop fixed, tests passed, coverage validated."
end

# ============================================================================
# DEFAULT TASK
# ============================================================================

# Default: Run all tests
desc "Default task: Run all tests"
task default: %i[test] do
  puts "\n✓ All tests completed successfully!"
end

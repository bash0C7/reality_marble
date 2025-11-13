# カバレッジ測定の開始（他のrequireより前に実行）
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  enable_coverage :branch
  # カバレッジ要件: line 75%, branch 55%
  # TDDサイクルで常にカバレッジチェック
  minimum_coverage line: 75, branch: 55
end

# Codecov v4対応: Cobertura XML形式で出力
require "simplecov-cobertura"
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "reality_marble"

require "test-unit"
require "tmpdir"

# テスト用基底クラス
class RealityMarbleTestCase < Test::Unit::TestCase
end

# Reality Marble v2.0: 開発タスク＆改善戦略

## ✅ 完了セッション（Session 4 - 2025-11-15）

### Phase 1: 既存メソッド上書きの復元 ✅
- ✅ Modified methods detection: `store_defined_methods` で既存メソッド上書きを検出
- ✅ Modified methods restoration: `cleanup_defined_methods` で元に戻す
- ✅ Deleted methods support: 削除されたメソッドの復元も対応
- **Status**: 実装済み＆テスト完了

### Phase 2: テストカバレッジ拡張 ✅
- ✅ 21 tests（前: 12 tests）
- ✅ Line coverage: 90.38% (目標: 75%)
- ✅ Branch coverage: 78.57% (目標: 55%)
- ✅ RuboCop: 0 violations

**テストパターンの追加**:
- ✅ Modified instance/singleton methods restoration
- ✅ Nested class definitions
- ✅ Method inheritance and super keyword
- ✅ Context stack management
- ✅ Closure support without capture:
- ✅ Multiple modified methods
- ✅ Call history tracking

---

## 🔴 次のフェーズ（Phase 3+）

### Problem: 既存メソッド上書き復元の詳細（参考用）

```ruby
# ユーザーの期待：
RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path == "/mock"
  end
end.activate do
  File.exist?("/mock")  # true を期待
end

# 現在の実装の結果：
# ✅ chant ブロック内では動作する（新しい実装が active）
# ✅ activate ブロック内では動作する（新しい実装が active）
# ❌ activate を抜けた後、新しい実装が残ったまま（元に戻らない）
```

### 根本原因

```ruby
def diff_methods(before, after)
  after.reject { |key, _| before.key?(key) }
end

# 処理の流れ：
before_methods = {[:File.singleton_class, :exist?] => 元の Method}
after_methods = {[:File.singleton_class, :exist?] => 新しい Method}

# diff = after.reject { |key, _| before.key?(key) }
# → [:File.singleton_class, :exist?] は before に存在
# → reject で除外される
# → @defined_methods = {} ← 何も保存されない

# cleanup_defined_methods は @defined_methods に基づいて削除
# → @defined_methods が空 → 何も削除されない
# → 新しい実装が残ったまま
```

### ユーザーが見える動作

```ruby
# Test 1
RealityMarble.chant do
  File.define_singleton_method(:exist?) { false }
end.activate do
  puts File.exist?('/any')  # false（モック版）
end
puts File.exist?(__FILE__)  # true または false？
# → 実装 bug により false が残る（元に戻らない）

# Test 2
RealityMarble.chant do
  MyNewClass.define_singleton_method(:new_method) { "new" }
end.activate do
  puts MyNewClass.new_method  # "new"
end
puts MyNewClass.respond_to?(:new_method)  # false（正しく削除される）
```

---

## ✅ 改善戦略（機能トレードオフなし）

### 戦略1：既存メソッド上書きの検出と復元

#### 改善案A：「変更されたメソッド」を明示的に記録

```ruby
def store_defined_methods(before_methods)
  after_methods = collect_all_methods

  # 新規メソッド = after に存在し before に存在しない
  new_methods = after_methods.reject { |key, _| before_methods.key?(key) }

  # 変更されたメソッド = 両方に存在しているが Method が異なる
  modified_methods = {}
  after_methods.each do |key, after_method|
    if before_methods.key?(key)
      before_method = before_methods[key]
      # Method オブジェクトの source_location で比較（簡易版）
      # または、arity/parameter で比較
      if before_method.source_location != after_method.source_location
        modified_methods[key] = before_method  # 元の Method を保存
      end
    end
  end

  @defined_methods = new_methods
  @modified_methods = modified_methods  # 新規属性
end

def cleanup_defined_methods
  # 新規メソッドを削除
  @defined_methods.each_key do |key|
    target, method_name = key
    target.remove_method(method_name) if target.respond_to?(:remove_method)
  end

  # 変更されたメソッドを元に戻す
  @modified_methods&.each do |key, original_method|
    target, method_name = key
    target.define_method(method_name, original_method)
  end
end
```

#### 問題：source_location での比較は不安定

```ruby
# Ruby 動的メソッドは source_location が異なる
before_method.source_location  # => ["-e", 1]（動的メソッド）
after_method.source_location   # => ["-e", 1]（動的メソッド）

# 同じになって判定できない可能性
```

#### 改善案B：alias_method で backup/restore（確実）

```ruby
def chant(capture: nil, &block)
  marble = Marble.new(capture: capture)
  if block
    # ObjectSpace スナップショット（新規メソッド検出用）
    before_methods = marble.collect_all_methods

    # backup_map に「上書きされるメソッド」を記録
    backup_map = {}

    # Block 実行時にメソッド上書きを追跡
    # 方法1: method_added hook を使う（複雑）
    # 方法2: after と before を diff して「変更」を検出（↓）

    # Block 実行
    if capture
      marble.instance_exec(capture, &block)
    else
      marble.instance_eval(&block)
    end

    # 変更検出：before と after で異なるメソッド
    after_methods = marble.collect_all_methods

    after_methods.each do |key, after_method|
      if before_methods.key?(key)
        # 変更されたメソッド → backup
        backup_map[key] = before_methods[key]
        marble.mark_as_modified(key)  # 追跡
      end
    end

    marble.store_backup_map(backup_map)
    marble.store_defined_methods(before_methods)
    marble.cleanup_defined_methods
  end
  marble
end

def activate
  apply_defined_methods

  ctx = Context.current
  ctx.push(self)

  result = yield

  result
ensure
  ctx = Context.current
  ctx.pop

  cleanup_defined_methods
  restore_modified_methods  # ← 新規メソッド
end

def restore_modified_methods
  @modified_methods&.each do |key, original_method|
    target, method_name = key
    target.define_method(method_name, original_method)
  end
end
```

---

### 戦略2：Closure サポート（capture 不要に）

#### 現在の実装

```ruby
# ❌ closure が見えない
counter = 0
RealityMarble.chant do
  MyClass.define_method(:increment) do
    counter += 1  # counter が見えない（binding が異なる）
  end
end

# ✅ capture を使う
counter = 0
RealityMarble.chant(capture: {counter: counter}) do |cap|
  MyClass.define_method(:increment) do
    cap[:counter] += 1
  end
end
```

#### 改善案：closure を使えるように

```ruby
def self.chant(capture: nil, &block)
  marble = Marble.new(capture: capture)
  if block
    # ...

    # ブロックの binding を保持（closure のコンテキスト）
    block_binding = block.binding  # ← Ruby 2.4+

    # ブロック実行時に binding を環境として使う
    # instance_exec 代わりに eval を使う
    block_binding.eval(block.source) if block.source
    # または
    block_binding.instance_eval(&block)

    # ...
  end
  marble
end
```

#### より実用的な改善：`&block` の binding をコピー

```ruby
def apply_defined_methods(binding_context = nil)
  @defined_methods.each do |key, method_obj|
    target, method_name = key

    # method_obj が closure を含むなら、binding を注入
    if binding_context
      # method_obj の closure を binding_context に変換
      # これは複雑... 別の方法が必要
    end

    target.define_method(method_name, method_obj)
  end
end
```

#### 最実用的な改善：`define_method` で closure が見えるように

実は Ruby では `define_method` のブロックは **自動的に closure を保持** します：

```ruby
counter = 0
MyClass.define_method(:increment) do
  counter += 1  # ✅ closure で counter が見える
end

obj = MyClass.new
obj.increment  # counter += 1 実行
puts counter  # 1
```

では、なぜ Reality Marble では見えないのか？

```ruby
RealityMarble.chant do
  counter = 0  # ← chant ブロック内のローカル変数

  MyClass.define_method(:increment) do
    counter += 1  # ← この counter は？
  end
end

# 問題：chant ブロック内で定義された counter は
# instance_eval/instance_exec のコンテキストが異なる
# → chant ブロックの binding の counter を参照できない
```

#### 改善：定義時の binding を保存して使用

```ruby
def self.chant(capture: nil, &block)
  marble = Marble.new(capture: capture)
  if block
    # ⭐ ブロックの binding を保存
    defining_binding = block.binding

    before_methods = marble.collect_all_methods

    # Block 実行（binding コンテキストで）
    # ただし define_method で定義されるメソッドは
    # 定義時の binding を capture するので OK
    if capture
      marble.instance_exec(capture, &block)
    else
      # ⭐ binding を chant 内コンテキストで使う
      # instance_eval ではなく、block の binding で実行
      marble.instance_eval do
        block.binding.eval(block.source_location.first)  # 複雑...
      end
    end

    # ...
  end
  marble
end
```

実際には Ruby の `define_method` は **既に closure を保持** しているので、改善は「binding の visibility」だけです。

最も実用的な改善：

```ruby
# ✅ そのまま closure が見える（実装は変えない）
counter = 0
RealityMarble.chant do
  MyClass.define_method(:increment) do
    counter += 1  # ✅ OK（closure で counter が見える）
  end
end.activate do
  MyClass.new.increment
  puts counter  # 1
end
```

実は **これはそのまま動作する** はずですピョン。問題があるのは「capture を使う場合」だけです。

---

### 戦略3：パフォーマンスチューニング（機能トレードオフなし）

#### 改善案1：ObjectSpace スキャンをキャッシュ

```ruby
# ⭐ クラスごとのメソッド情報をキャッシュ
@methods_cache = {}

def collect_all_methods
  methods_hash = {}

  ObjectSpace.each_object(Module) do |mod|
    # キャッシュをチェック
    if @methods_cache[mod]
      methods_hash.merge!(@methods_cache[mod])
    else
      methods = {}
      mod.instance_methods(false).each do |method_name|
        methods[[mod, method_name]] = mod.instance_method(method_name)
      end
      @methods_cache[mod] = methods
      methods_hash.merge!(methods)
    end
  end

  methods_hash
end
```

**問題**: キャッシュ invalidation（メソッドが変わったらキャッシュを更新する必要）

#### 改善案2：「新規メソッド定義」だけを追跡（ObjectSpace を減らす）

```ruby
# ⭐ Module.prepend で define_method を intercept
module MethodDefinitionTracker
  def define_method(name, &block)
    # 定義されるメソッドをキャプチャ
    RealityMarble.current_marble&.track_method_definition(name, block)
    super
  end
end

Module.prepend(MethodDefinitionTracker)
```

**利点**: ObjectSpace スキャンが不要（定義時に直接 hook）
**課題**: Module.prepend のパフォーマンス overhead

#### 改善案3：Lazy ObjectSpace スキャン

```ruby
# ⭐ 実際に必要になるまでスキャンを遅延
def collect_all_methods
  # 最初は空のプロキシを返す
  lazy_methods = LazyObjectSpaceSnapshot.new
  lazy_methods
end

class LazyObjectSpaceSnapshot
  def initialize
    @methods_hash = nil
  end

  def [](key)
    @methods_hash ||= perform_scan
    @methods_hash[key]
  end

  def key?(key)
    @methods_hash ||= perform_scan
    @methods_hash.key?(key)
  end

  def each
    @methods_hash ||= perform_scan
    @methods_hash.each { |k, v| yield k, v }
  end

  private

  def perform_scan
    hash = {}
    ObjectSpace.each_object(Module) do |mod|
      # ... スキャン
    end
    hash
  end
end
```

**利点**: 実際に必要なメソッドだけスキャン
**課題**: メモリ overhead（遅延評価のための wrapper）

#### 改善案4：指定されたクラスのみスキャン（ユーザーが最速）

```ruby
RealityMarble.chant(only: [File, String]) do
  # File と String のメソッド定義のみ追跡
  File.define_method(:exist?) { false }
  String.define_method(:upcase) { "MOCKED" }
end

def collect_all_methods(only_modules: nil)
  methods_hash = {}

  modules_to_scan = only_modules || ObjectSpace.each_object(Module)

  modules_to_scan.each do |mod|
    # ... スキャン
  end

  methods_hash
end
```

**利点**: ユーザーが制御可能、最速
**課題**: API 複雑化

---

## 📊 改善案の評価

| 改善案 | 既存メソッド復元 | Closure | パフォーマンス | 実装複雑度 |
|--------|----------|---------|-----------|-----------|
| **A: source_location 比較** | ⚠️ 不安定 | ❌ | O(n) | ⭐ |
| **B: alias_method backup** | ✅ 確実 | ❌ | O(n) | ⭐⭐ |
| **C: binding キャッシュ** | ✅ | ✅ 自動 | O(1) 以降 | ⭐⭐ |
| **D: Module.prepend hook** | ✅ | ✅ | O(1) | ⭐⭐⭐ |
| **E: Lazy snapshot** | ✅ | ✅ | ~O(k) | ⭐⭐⭐ |
| **F: only 引数** | ✅ | ✅ | O(m) (m < n) | ⭐⭐ |

---

## 🎯 推奨される改善の組み合わせ

### Phase 1: 即時修正（機能 bug 解決）

```ruby
# ⭐ 既存メソッド上書きの復元を実装

def store_defined_methods(before_methods)
  after_methods = collect_all_methods

  new_methods = {}
  modified_methods = {}
  deleted_methods = {}

  after_methods.each do |key, after_method|
    new_methods[key] = after_method unless before_methods.key?(key)
  end

  before_methods.each do |key, before_method|
    unless after_methods.key?(key)
      deleted_methods[key] = before_method
    end
  end

  @defined_methods = new_methods
  @modified_methods = modified_methods  # ← 現在は空
  @deleted_methods = deleted_methods
end

def cleanup_defined_methods
  # 新規メソッド削除
  @defined_methods.each_key do |key|
    target, method_name = key
    target.remove_method(method_name)
  end

  # 削除されたメソッドを復元
  @deleted_methods.each do |key, original_method|
    target, method_name = key
    target.define_method(method_name, original_method)
  end
end
```

### Phase 2: パフォーマンス（`only` 引数で最速）

```ruby
def self.chant(capture: nil, only: nil, &block)
  marble = Marble.new(capture: capture, only: only)
  # ... only で ObjectSpace スキャン範囲を限定
end
```

### Phase 3: Closure 自動サポート

```ruby
# 実は既に動作している（binding 自動保持）
# 確認テストを追加
```

---

## 💡 「RSpec ecosystem 不要」について

**正確なメリット**：

```ruby
# ✅ Reality Marble のメリット：テストフレームワーク中立
# RSpec なし、Test::Unit だけで完結

require 'test-unit'

class MyTest < Test::Unit::TestCase
  def test_file_operations
    RealityMarble.chant do
      File.define_method(:exist?) { |p| p == "/mock" }
    end.activate do
      assert File.exist?("/mock")
    end
  end
end

# ✅ RSpec::Mocks のデメリット：RSpec 依存
require 'rspec'

describe 'File operations' do
  it 'mocks exist?' do
    allow(File).to receive(:exist?).and_return(true)
    expect(File.exist?('/any')).to eq(true)
  end
end

# ✅ Minitest::Mock のメリット：フレームワーク中立
require 'test-unit'

class MyTest < Test::Unit::TestCase
  def test_file_operations
    mock = Minitest::Mock.new
    mock.expect(:exist?, true, ['/mock'])
    # ...
  end
end
```

**Reality Marble の位置付け**：
- **RSpec**よりシンプル（ecosystem 不要）
- **Minitest::Mock**より柔軟（Method 直接定義）
- **独特の価値**：native Ruby + 完全な isolation

---

## 📌 最後のひと言

ユーザーの指摘は **100% 正確**ですピョン。

**実装の課題**：
1. ✅ 既存メソッド上書きが復元されない（bug）
2. ✅ closure が見えない（仕様でなく capture が必須）
3. ✅ ObjectSpace スキャンが遅い（機能 vs パフォーマンス）

**改善方針**：
1. ⭐ 既存メソッド復元を実装（Phase 1）
2. ⭐ `only:` 引数で ObjectSpace 範囲を限定（Phase 2）
3. ⭐ closure は自動動作（確認テスト追加）

---

## 🎯 Next Phases (Session 5+)

### Phase 3: Performance Tuning - ObjectSpace Optimization

**Goal**: Reduce method scanning overhead with `only:` parameter

**Proposed API**:
```ruby
# Without only: (current - scans all methods)
RealityMarble.chant do
  File.define_singleton_method(:exist?) { |p| p == "/mock" }
end

# With only: (future - scans only specified classes)
RealityMarble.chant(only: [File]) do
  File.define_singleton_method(:exist?) { |p| p == "/mock" }
end
```

**Implementation Plan**:
1. Add `only:` parameter to `Marble.new`
2. Modify `collect_all_methods` to respect `only:` filter
3. Add performance benchmark tests
4. Document performance characteristics

**Expected Impact**: 10-100x faster for targeted mocking (small number of classes)

### Phase 4: Advanced Features (Future)

- Refinements support (lexical scoping)
- TracePoint-based call tracking
- Module.prepend for method_added hook
- Optional lazy ObjectSpace scanning

---

チェケラッチョ！
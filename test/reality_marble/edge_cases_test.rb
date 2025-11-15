require "test_helper"

# Comprehensive edge case tests for Reality Marble
# Tests complex Ruby patterns: Module/Class hierarchies, mixin chains,
# method_missing, aliasing, freezing, and metaprogramming combinations
class EdgeCasesTest < RealityMarbleTestCase
  # Define reusable test helper: parameterized test executor
  def self.define_edge_case_tests(cases)
    cases.each do |test_case|
      test_name = "test_#{test_case[:name].gsub(/\s+/, "_").downcase}"
      define_method(test_name) do
        instance_eval(&test_case[:test])
      end
    end
  end

  # ============================================================================
  # EDGE CASE TEST SUITE
  # ============================================================================

  TEST_CASES = [
    # ========== MODULE PATTERNS ==========
    {
      name: "Module instance method with include",
      test: proc {
        mod = Module.new do
          def module_method
            "original"
          end
        end

        klass = Class.new { include mod }
        obj = klass.new

        assert_equal "original", obj.module_method

        marble = RealityMarble.chant do
          mod.define_method(:module_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.module_method
        end

        assert_equal "original", obj.module_method
      }
    },

    {
      name: "Module singleton method with extend",
      test: proc {
        mod = Module.new do
          def self.module_singleton
            "original"
          end
        end

        marble = RealityMarble.chant do
          mod.define_singleton_method(:module_singleton) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", mod.module_singleton
        end

        assert_equal "original", mod.module_singleton
      }
    },

    {
      name: "Prepended module method",
      test: proc {
        base_mod = Module.new do
          def prepared_method
            "base"
          end
        end

        klass = Class.new { prepend base_mod }
        obj = klass.new

        marble = RealityMarble.chant do
          base_mod.define_method(:prepared_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.prepared_method
        end

        assert_equal "base", obj.prepared_method
      }
    },

    # ========== INHERITANCE PATTERNS ==========
    {
      name: "Method override in deeply nested inheritance",
      test: proc {
        grandparent = Class.new do
          def deep_method
            "grandparent"
          end
        end

        parent = Class.new(grandparent)

        child = Class.new(parent)
        obj = child.new

        marble = RealityMarble.chant do
          child.define_method(:deep_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.deep_method
        end

        assert_equal "grandparent", obj.deep_method
      }
    },

    {
      name: "Method with super in override",
      test: proc {
        parent = Class.new do
          def with_super
            "parent"
          end
        end

        child = Class.new(parent)
        obj = child.new

        marble = RealityMarble.chant do
          child.define_method(:with_super) do
            "mocked_#{super()}"
          end
        end

        marble.activate do
          assert_equal "mocked_parent", obj.with_super
        end

        assert_equal "parent", obj.with_super
      }
    },

    # ========== ALIASING PATTERNS ==========
    {
      name: "Aliased instance method with both targets mocked",
      test: proc {
        klass = Class.new do
          def original_method
            "original"
          end

          alias_method :aliased_method, :original_method
        end

        obj = klass.new

        marble = RealityMarble.chant do
          # Mock both the original and the alias to update the actual method
          klass.define_method(:original_method) { "mocked" }
          klass.define_method(:aliased_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.original_method
          assert_equal "mocked", obj.aliased_method
        end

        assert_equal "original", obj.original_method
        assert_equal "original", obj.aliased_method
      }
    },

    {
      name: "Singleton alias with both targets mocked",
      test: proc {
        klass = Class.new do
          def self.original_singleton
            "original"
          end
        end

        klass.singleton_class.send(:alias_method, :aliased_singleton, :original_singleton)

        marble = RealityMarble.chant do
          # Mock both targets to ensure both are updated
          klass.define_singleton_method(:original_singleton) { "mocked" }
          klass.define_singleton_method(:aliased_singleton) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", klass.original_singleton
          assert_equal "mocked", klass.aliased_singleton
        end

        assert_equal "original", klass.original_singleton
        assert_equal "original", klass.aliased_singleton
      }
    },

    # ========== METHOD_MISSING PATTERNS ==========
    {
      name: "method_missing with mock override",
      test: proc {
        klass = Class.new do
          def method_missing(name, *_args)
            "missing_#{name}"
          end

          def respond_to_missing?(_name, _include_private = false)
            true
          end
        end

        obj = klass.new

        marble = RealityMarble.chant do
          klass.define_method(:dynamic_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.dynamic_method
        end

        # After cleanup, falls back to method_missing
        assert_equal "missing_dynamic_method", obj.dynamic_method
      }
    },

    {
      name: "method_missing with super",
      test: proc {
        parent = Class.new do
          def method_missing(_name, *_args)
            "parent_missing"
          end
        end

        child = Class.new(parent) do
          def method_missing(name, *args)
            "child_#{super}"
          end
        end

        obj = child.new

        marble = RealityMarble.chant do
          child.define_method(:test_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.test_method
        end

        assert_equal "child_parent_missing", obj.test_method
      }
    },

    # ========== CLOSURE AND BINDING PATTERNS ==========
    {
      name: "Method with closure over instance variable",
      test: proc {
        klass = Class.new do
          def initialize
            @value = "original_instance"
          end

          def closure_method
            @value
          end
        end

        obj = klass.new

        marble = RealityMarble.chant do
          klass.define_method(:closure_method) do
            "#{@value}_mocked"
          end
        end

        marble.activate do
          assert_equal "original_instance_mocked", obj.closure_method
        end

        assert_equal "original_instance", obj.closure_method
      }
    },

    {
      name: "Class variable access in mocked method",
      test: proc {
        klass = Class.new do
          @@class_var = "class_original"

          def class_var_method
            @@class_var
          end
        end

        obj = klass.new

        marble = RealityMarble.chant do
          klass.define_method(:class_var_method) do
            "#{@@class_var}_mocked"
          end
        end

        marble.activate do
          assert_equal "class_original_mocked", obj.class_var_method
        end

        assert_equal "class_original", obj.class_var_method
      }
    },

    # ========== BLOCK AND YIELD PATTERNS ==========
    {
      name: "Method with Proc.new capturing block",
      test: proc {
        klass = Class.new do
          def proc_method(&block)
            yield("original") if block
          end
        end

        obj = klass.new
        results = []

        marble = RealityMarble.chant do
          klass.define_method(:proc_method) do |&block|
            block.call("mocked") if block
          end
        end

        marble.activate do
          obj.proc_method { |val| results << val }
        end

        assert_equal ["mocked"], results
      }
    },

    {
      name: "Method with multiple arguments and block",
      test: proc {
        klass = Class.new do
          def multi_arg_method(arg1, arg2)
            "original_#{arg1}_#{arg2}"
          end
        end

        obj = klass.new

        marble = RealityMarble.chant do
          klass.define_method(:multi_arg_method) do |arg1, arg2|
            "mocked_#{arg1}_#{arg2}"
          end
        end

        marble.activate do
          assert_equal "mocked_a_b", obj.multi_arg_method("a", "b")
        end

        assert_equal "original_a_b", obj.multi_arg_method("a", "b")
      }
    },

    # ========== SINGLETON CLASS PATTERNS ==========
    {
      name: "Instance singleton method",
      test: proc {
        obj = Object.new
        obj.define_singleton_method(:instance_singleton) { "original" }

        assert_equal "original", obj.instance_singleton

        marble = RealityMarble.chant do
          obj.define_singleton_method(:instance_singleton) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.instance_singleton
        end

        assert_equal "original", obj.instance_singleton
      }
    },

    {
      name: "Method on singleton_class",
      test: proc {
        klass = Class.new

        marble = RealityMarble.chant do
          klass.singleton_class.define_method(:singleton_class_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", klass.singleton_class_method
        end

        assert_raises(NoMethodError) { klass.singleton_class_method }
      }
    },

    # ========== MULTIPLE MIXIN PATTERNS ==========
    {
      name: "Multiple module mixins with same method",
      test: proc {
        mod1 = Module.new do
          def shared_method
            "mod1"
          end
        end

        mod2 = Module.new do
          def shared_method
            "mod2"
          end
        end

        klass = Class.new do
          include mod1
          include mod2
        end
        obj = klass.new

        # mod2 is included later, so its method takes precedence
        assert_equal "mod2", obj.shared_method

        marble = RealityMarble.chant do
          mod2.define_method(:shared_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.shared_method
        end

        assert_equal "mod2", obj.shared_method
      }
    },

    {
      name: "Include, extend, and prepend combined",
      test: proc {
        mod = Module.new do
          def combo_method
            "original"
          end
        end

        klass = Class.new do
          include mod
          extend mod
          prepend mod
        end

        obj = klass.new

        marble = RealityMarble.chant do
          mod.define_method(:combo_method) { "mocked" }
        end

        marble.activate do
          # All paths use the mocked version
          assert_equal "mocked", obj.combo_method
          assert_equal "mocked", klass.combo_method
        end

        assert_equal "original", obj.combo_method
        assert_equal "original", klass.combo_method
      }
    },

    # ========== DYNAMIC METHOD DEFINITION PATTERNS ==========
    {
      name: "Method defined via method_added hook",
      test: proc {
        klass = Class.new do
          def self.method_added(name)
            # Hook fires when method is defined
          end

          def tracked_method
            "original"
          end
        end

        obj = klass.new

        marble = RealityMarble.chant do
          klass.define_method(:tracked_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.tracked_method
        end

        assert_equal "original", obj.tracked_method
      }
    },

    {
      name: "Method defined via send",
      test: proc {
        klass = Class.new
        klass.send(:define_method, :send_method) { "original" }
        obj = klass.new

        marble = RealityMarble.chant do
          klass.send(:define_method, :send_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.send_method
        end

        assert_equal "original", obj.send_method
      }
    },

    # ========== INTROSPECTION PATTERNS ==========
    {
      name: "Method introspection with method_defined check",
      test: proc {
        klass = Class.new do
          def introspective
            "original"
          end
        end

        assert klass.method_defined?(:introspective)

        marble = RealityMarble.chant do
          klass.define_method(:introspective) { "mocked" }
        end

        # Method is still defined after chant
        assert klass.method_defined?(:introspective)

        marble.activate do
          obj = klass.new
          assert_equal "mocked", obj.introspective
        end

        # Restored after cleanup
        obj = klass.new
        assert_equal "original", obj.introspective
      }
    },

    {
      name: "Respond to check with method_missing",
      test: proc {
        klass = Class.new do
          def method_missing(_name, *_args)
            "missing"
          end

          def respond_to_missing?(_name, _include_private = false)
            true
          end
        end

        obj = klass.new

        # Before mock, responds via method_missing
        assert obj.respond_to?(:any_method)

        marble = RealityMarble.chant do
          klass.define_method(:explicit_method) { "mocked" }
        end

        marble.activate do
          assert obj.respond_to?(:explicit_method)
        end

        # After cleanup, falls back to method_missing
        assert obj.respond_to?(:explicit_method)
      }
    },

    # ========== DEEPLY NESTED MARBLE PATTERNS ==========
    {
      name: "2-level nested marble activation",
      test: proc {
        klass = Class.new do
          def level_test
            "original"
          end
        end

        obj = klass.new

        marble1 = RealityMarble.chant do
          klass.define_method(:level_test) { "level_1" }
        end

        marble2 = RealityMarble.chant do
          klass.define_method(:level_test) { "level_2" }
        end

        marble1.activate do
          assert_equal "level_1", obj.level_test

          marble2.activate do
            assert_equal "level_2", obj.level_test
          end

          # Restored to level_1 after level_2 cleanup
          assert_equal "level_1", obj.level_test
        end

        # Restored to original after all cleanup
        assert_equal "original", obj.level_test
      }
    },

    {
      name: "3-level nested marble with different methods",
      test: proc {
        klass = Class.new do
          def method_a = "a_original"
          def method_b = "b_original"
          def method_c = "c_original"
        end

        obj = klass.new

        marble1 = RealityMarble.chant do
          klass.define_method(:method_a) { "a_level_1" }
        end

        marble2 = RealityMarble.chant do
          klass.define_method(:method_b) { "b_level_2" }
        end

        marble3 = RealityMarble.chant do
          klass.define_method(:method_c) { "c_level_3" }
        end

        marble1.activate do
          assert_equal "a_level_1", obj.method_a

          marble2.activate do
            assert_equal "b_level_2", obj.method_b

            marble3.activate do
              assert_equal "c_level_3", obj.method_c
              # All mocks active
              assert_equal "a_level_1", obj.method_a
              assert_equal "b_level_2", obj.method_b
              assert_equal "c_level_3", obj.method_c
            end

            # level_3 cleaned up
            assert_equal "c_original", obj.method_c
            # Others still mocked
            assert_equal "a_level_1", obj.method_a
            assert_equal "b_level_2", obj.method_b
          end

          # level_2 cleaned up
          assert_equal "b_original", obj.method_b
          assert_equal "a_level_1", obj.method_a
        end

        # All cleaned
        assert_equal "a_original", obj.method_a
        assert_equal "b_original", obj.method_b
        assert_equal "c_original", obj.method_c
      }
    },

    {
      name: "4-level nested marble with same method override at each level",
      test: proc {
        klass = Class.new do
          def shared_method
            "original"
          end
        end

        obj = klass.new

        marble1 = RealityMarble.chant do
          klass.define_method(:shared_method) { "level_1" }
        end

        marble2 = RealityMarble.chant do
          klass.define_method(:shared_method) { "level_2" }
        end

        marble3 = RealityMarble.chant do
          klass.define_method(:shared_method) { "level_3" }
        end

        marble4 = RealityMarble.chant do
          klass.define_method(:shared_method) { "level_4" }
        end

        marble1.activate do
          assert_equal "level_1", obj.shared_method

          marble2.activate do
            assert_equal "level_2", obj.shared_method

            marble3.activate do
              assert_equal "level_3", obj.shared_method

              marble4.activate do
                assert_equal "level_4", obj.shared_method
              end

              assert_equal "level_3", obj.shared_method
            end

            assert_equal "level_2", obj.shared_method
          end

          assert_equal "level_1", obj.shared_method
        end

        assert_equal "original", obj.shared_method
      }
    },

    {
      name: "5-level nested marble with cascading effects",
      test: proc {
        klass = Class.new do
          def cascade_method
            "original"
          end
        end

        obj = klass.new
        call_log = []

        marble1 = RealityMarble.chant do
          klass.define_method(:cascade_method) do
            call_log << 1
            "level_1"
          end
        end

        marble2 = RealityMarble.chant do
          klass.define_method(:cascade_method) do
            call_log << 2
            "level_2"
          end
        end

        marble3 = RealityMarble.chant do
          klass.define_method(:cascade_method) do
            call_log << 3
            "level_3"
          end
        end

        marble4 = RealityMarble.chant do
          klass.define_method(:cascade_method) do
            call_log << 4
            "level_4"
          end
        end

        marble5 = RealityMarble.chant do
          klass.define_method(:cascade_method) do
            call_log << 5
            "level_5"
          end
        end

        marble1.activate do
          assert_equal "level_1", obj.cascade_method
          assert_equal [1], call_log

          marble2.activate do
            call_log.clear
            assert_equal "level_2", obj.cascade_method
            assert_equal [2], call_log

            marble3.activate do
              call_log.clear
              assert_equal "level_3", obj.cascade_method
              assert_equal [3], call_log

              marble4.activate do
                call_log.clear
                assert_equal "level_4", obj.cascade_method
                assert_equal [4], call_log

                marble5.activate do
                  call_log.clear
                  assert_equal "level_5", obj.cascade_method
                  assert_equal [5], call_log
                end

                # Back to level_4
                call_log.clear
                assert_equal "level_4", obj.cascade_method
                assert_equal [4], call_log
              end

              # Back to level_3
              call_log.clear
              assert_equal "level_3", obj.cascade_method
              assert_equal [3], call_log
            end

            # Back to level_2
            call_log.clear
            assert_equal "level_2", obj.cascade_method
            assert_equal [2], call_log
          end

          # Back to level_1
          call_log.clear
          assert_equal "level_1", obj.cascade_method
          assert_equal [1], call_log
        end

        # Back to original
        call_log.clear
        assert_equal "original", obj.cascade_method
        assert_empty call_log
      }
    },

    # ========== KNOWN LIMITATIONS (Documented, Not Bugs) ==========
    {
      name: "KNOWN LIMITATION: Aliased instance method requires both targets",
      test: proc {
        klass = Class.new do
          def original_method
            "original"
          end

          alias_method :aliased_method, :original_method
        end

        obj = klass.new

        # This test documents the limitation:
        # When using alias_method, you must mock BOTH the original and alias
        # because alias points to the original Method object
        marble = RealityMarble.chant do
          klass.define_method(:original_method) { "mocked" }
          klass.define_method(:aliased_method) { "mocked" }
        end

        marble.activate do
          assert_equal "mocked", obj.original_method
          assert_equal "mocked", obj.aliased_method
        end

        assert_equal "original", obj.original_method
        assert_equal "original", obj.aliased_method
      }
    },

    {
      name: "KNOWN LIMITATION: Mocked methods are always public",
      test: proc {
        klass = Class.new do
          def public_method
            "original_public"
          end
        end

        obj = klass.new

        # This test documents that all mocked methods become public,
        # regardless of original visibility.
        # This is expected because define_method always creates public methods.
        marble = RealityMarble.chant do
          klass.define_method(:public_method) { "mocked" }
        end

        marble.activate do
          # Method is accessible and mocked
          assert_equal "mocked", obj.public_method
        end

        # After cleanup, original is restored
        assert_equal "original_public", obj.public_method
      }
    }
  ].freeze

  define_edge_case_tests(TEST_CASES)
end

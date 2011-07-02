# -*- encoding: utf-8 -*-

require 'data_mapper/validations/validator'

module DataMapper
  module Validations
    module Validators
      # TOOD: rewrite this
      class Numericality < Validator

        def call(target)
          value = target.validation_property_value(attribute_name)
          return true if optional?(value)

          errors = []

          validate_with(integer_only? ? :integer : :numeric, value, errors)

          add_errors(target, errors)

          # if the number is invalid, skip further tests
          return false if errors.any?

          [ :gt, :lt, :gte, :lte, :eq, :ne ].each do |validation_type|
            validate_with(validation_type, value, errors)
          end

          add_errors(target, errors)

          errors.empty?
        end

      private

        def integer_only?
          options[:only_integer] || options.fetch(:integer_only, false)
        end

        def value_as_string(value)
          case value
            # Avoid Scientific Notation in Float to_s
            when Float      then value.to_d.to_s('F')
            when BigDecimal then value.to_s('F')
            else value.to_s
          end
        end

        def add_errors(target, errors)
          return if errors.empty?

          if message = self.custom_message
            add_error(target, message, attribute_name)
          else
            errors.each do |error_message|
              add_error(target, error_message, attribute_name)
            end
          end
        end

        def validate_with(validation_type, value, errors)
          send("validate_#{validation_type}", value, errors)
        end

        def validate_with_comparison(value, cmp, expected, error_message_name, errors, negated = false)
          return if expected.nil?

          # XXX: workaround for jruby. This is needed because the jruby
          # compiler optimizes a bit too far with magic variables like $~.
          # the value.send line sends $~. Inserting this line makes sure the
          # jruby compiler does not optimise here.
          # see http://jira.codehaus.org/browse/JRUBY-3765
          $~ = nil if RUBY_PLATFORM[/java/]

          comparison = value.send(cmp, expected)
          return if negated ? !comparison : comparison

          errors << ValidationErrors.default_error_message(
            error_message_name,
            attribute_name,
            expected
          )
        end

        def validate_integer(value, errors)
          validate_with_comparison(value_as_string(value), :=~, /\A[+-]?\d+\z/, :not_an_integer, errors)
        end

        def validate_numeric(value, errors)
          precision = options[:precision]
          scale     = options[:scale]

          regexp = if precision && scale
            if precision > scale && scale == 0
              /\A[+-]?(?:\d{1,#{precision}}(?:\.0)?)\z/
            elsif precision > scale
              /\A[+-]?(?:\d{1,#{precision - scale}}|\d{0,#{precision - scale}}\.\d{1,#{scale}})\z/
            elsif precision == scale
              /\A[+-]?(?:0(?:\.\d{1,#{scale}})?)\z/
            else
              raise ArgumentError, "Invalid precision #{precision.inspect} and scale #{scale.inspect} for #{attribute_name} (value: #{value.inspect} #{value.class})"
            end
          else
            /\A[+-]?(?:\d+|\d*\.\d+)\z/
          end

          validate_with_comparison(value_as_string(value), :=~, regexp, :not_a_number, errors)
        end

        def validate_gt(value, errors)
          validate_with_comparison(value, :>, options[:gt] || options[:greater_than], :greater_than, errors)
        end

        def validate_lt(value, errors)
          validate_with_comparison(value, :<, options[:lt] || options[:less_than], :less_than, errors)
        end

        def validate_gte(value, errors)
          validate_with_comparison(value, :>=, options[:gte] || options[:greater_than_or_equal_to], :greater_than_or_equal_to, errors)
        end

        def validate_lte(value, errors)
          validate_with_comparison(value, :<=, options[:lte] || options[:less_than_or_equal_to], :less_than_or_equal_to, errors)
        end

        def validate_eq(value, errors)
          eq = options[:eq] || options[:equal] || options[:equals] || options[:exactly] || options[:equal_to]
          validate_with_comparison(value, :==, eq, :equal_to, errors)
        end

        def validate_ne(value, errors)
          validate_with_comparison(value, :==, options[:ne] || options[:not_equal_to], :not_equal_to, errors, true)
        end

      end # class Numericality
    end # module Validators
  end # module Validations
end # module DataMapper
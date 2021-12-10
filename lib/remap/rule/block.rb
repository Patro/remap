# frozen_string_literal: true

module Remap
  class Rule
    using State::Extension

    class Block < Unit
      # @return [Array<Rule>]
      attribute :rules, [Types::Rule]

      # Represents a non-empty define block with one or more rules
      # Calls every {#rules} with state and merges the output
      #
      # @param state [State]
      #
      # @return [State]
      def call(state, &error)
        unless block_given?
          raise ArgumentError, "Block#call(state, &error) requires a block"
        end

        if rules.empty?
          return state.except(:value)
        end

        rules.map do |rule|
          rule.call(state) do |failure|
            return error[failure]
          end
        end.reduce(&:combine)
      end
    end
  end
end
# frozen_string_literal: true

module Remap
  class Rule
    class Collection
      using State::Extension

      # Represents a non-empty rule block
      #
      # @example A non-empty collection
      #   class Mapper < Remap::Base
      #     define do
      #       map do
      #         map :a1, to: :b1
      #         map :a2, to: :b2
      #       end
      #     end
      #   end
      #
      #   Mapper.call({ a1: 1, a2: 2 }).result # => { b1: 1, b2: 2 }
      class Filled < Unit
        # @return [Array<Rule>]
        attribute :rules, [Types.Interface(:call)], min_size: 1

        # Represents a non-empty define block with one or more rules
        # Calls every {#rules} with state and merges the output
        #
        # @param state [State]
        #
        # @return [State]
        def call(state)
          rules.map do |rule|
            rule.call(state)
          end.reduce(&:combine)
        end
      end
    end
  end
end

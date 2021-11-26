# frozen_string_literal: true

module Remap
  class Rule
    class Set < self
      using State::Extension

      attribute :value, Types.Interface(:call)
      attribute :path, Path

      # Returns {value} mapped to {path} regardless of input
      #
      # @param state [State]
      #
      # @example Given an option
      #   class Mapper < Remap::Base
      #     option :name
      #
      #     define do
      #       set [:person, :name], to: option(:name)
      #     end
      #   end
      #
      #   Mapper.call(input, name: "John") # => { person: { name: "John" } }
      #
      # @example Given a value
      #   class Mapper < Remap::Base
      #     define do
      #       set [:api_key], to: value("ABC-123")
      #     end
      #   end
      #
      #   Mapper.call(input) # => { api_key: "ABC-123" }
      #
      # @return [State]
      def call(state)
        path.call(state) do
          value.call(state)
        end
      end
    end
  end
end

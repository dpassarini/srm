module PricingEngine
  module Strategies
    class Duplicata < Base
      def initialize(base_spread = 0.0150)
        super(base_spread)
      end
    end
  end
end

module PricingEngine
  module Strategies
    class Cheque < Base
      def initialize(base_spread = 0.0250)
        super(base_spread)
      end
    end
  end
end

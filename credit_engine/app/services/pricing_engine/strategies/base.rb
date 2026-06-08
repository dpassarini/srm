module PricingEngine
  module Strategies
    class Base
      attr_reader :base_spread

      def initialize(base_spread)
        @base_spread = base_spread
      end

      # Returns the spread to be applied.
      def spread_applied(_receivable_data = {})
        base_spread
      end

      # Calculates Net Value (Present Value) using compounding formula:
      # Net Value = Face Value / (1 + Base Rate + Spread)^Prazo
      def calculate_net_value(face_value, base_rate, spread, prazo_meses)
        denominator = (1.0 + base_rate.to_f + spread.to_f) ** prazo_meses.to_f
        (face_value.to_f / denominator).round(4)
      end
    end
  end
end

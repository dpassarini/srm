require "bigdecimal"

module PricingEngine
  class Calculator
    # Calculates a single receivable's present value
    def self.calculate_receivable(identifier: nil, face_value:, due_date:, receivable_type_code:, currency_code:, payment_currency_code:, base_rate: 0.0, operation_date: Date.today)
      face_value = BigDecimal(face_value.to_s)
      base_rate = BigDecimal(base_rate.to_s)
      due_date = due_date.to_date
      operation_date = operation_date.to_date

      # Validate date
      days = (due_date - operation_date).to_i
      if days < 0
        raise "Data de vencimento (#{due_date}) não pode ser anterior à data da operação (#{operation_date})"
      end

      prazo_meses = days / 30.0

      # Fetch ReceivableType and spread
      type_record = ReceivableType.find_by!(code: receivable_type_code)
      spread = type_record.base_spread

      # Resolve pricing strategy
      strategy_class = case receivable_type_code.to_s.downcase
      when "duplicata"
                         PricingEngine::Strategies::Duplicata
      when "cheque"
                         PricingEngine::Strategies::Cheque
      else
                         PricingEngine::Strategies::Base
      end

      strategy = strategy_class.new(spread)
      spread_applied = strategy.spread_applied

      # Calculate net value in original currency
      net_value_original = strategy.calculate_net_value(face_value, base_rate, spread_applied, prazo_meses)

      # Cross-currency conversion
      exchange_rate = nil
      net_value_payment = net_value_original

      if currency_code != payment_currency_code
        exchange_rate = find_exchange_rate(currency_code, payment_currency_code, operation_date)
        net_value_payment = (BigDecimal(net_value_original.to_s) * BigDecimal(exchange_rate.to_s)).round(4).to_f
      end

      {
        identifier: identifier,
        face_value: face_value.to_f,
        net_value_original: net_value_original.to_f,
        net_value: net_value_payment.to_f,
        due_date: due_date,
        days_to_maturity: days,
        spread_applied: spread_applied.to_f,
        base_rate_applied: base_rate.to_f,
        exchange_rate_applied: exchange_rate,
        receivable_type_id: type_record.id,
        currency_id: Currency.find_by!(code: currency_code).id
      }
    end

    # Calculates a batch of receivables and totals
    def self.calculate_operation(assignee:, payment_currency_code:, receivables:, base_rate: 0.0, operation_date: Date.today)
      payment_curr = Currency.find_by!(code: payment_currency_code)

      calculated_receivables = receivables.map do |rec|
        rec = rec.with_indifferent_access
        calculate_receivable(
          identifier: rec[:identifier],
          face_value: rec[:face_value],
          due_date: rec[:due_date],
          receivable_type_code: rec[:receivable_type_code],
          currency_code: rec[:currency_code] || payment_currency_code,
          payment_currency_code: payment_currency_code,
          base_rate: base_rate,
          operation_date: operation_date
        )
      end

      total_face_value = calculated_receivables.sum { |r| r[:face_value] }
      total_net_value = calculated_receivables.sum { |r| r[:net_value] }

      {
        assignee: assignee,
        payment_currency_id: payment_curr.id,
        total_face_value: total_face_value.round(4).to_f,
        total_net_value: total_net_value.round(4).to_f,
        receivables_attributes: calculated_receivables
      }
    end

    # Finds exchange rate from from_code to to_code for a given date
    def self.find_exchange_rate(from_code, to_code, date)
      return 1.0 if from_code == to_code

      from_curr = Currency.find_by(code: from_code)
      to_curr = Currency.find_by(code: to_code)

      raise "Moeda de origem não encontrada: #{from_code}" unless from_curr
      raise "Moeda de destino não encontrada: #{to_code}" unless to_curr

      # Find closest exchange rate equal or prior to the date
      rate_record = ExchangeRate.where(from_currency: from_curr, to_currency: to_curr)
                               .where("reference_date <= ?", date)
                               .order(reference_date: :desc)
                               .first

      unless rate_record
        # Try reverse exchange rate
        reverse_record = ExchangeRate.where(from_currency: to_curr, to_currency: from_curr)
                                     .where("reference_date <= ?", date)
                                     .order(reference_date: :desc)
                                     .first
        if reverse_record
          return (1.0 / reverse_record.rate.to_f).round(8)
        else
          raise "Taxa de câmbio de #{from_code} para #{to_code} não encontrada para a data #{date}"
        end
      end

      rate_record.rate.to_f
    end
  end
end

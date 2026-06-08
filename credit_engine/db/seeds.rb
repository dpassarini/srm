# Seeds para o SRM Credit Engine

puts "== Seed: Criando moedas padrão (BRL e USD)..."
brl = Currency.find_or_create_by!(code: "BRL") do |c|
  c.name = "Real Brasileiro"
  c.symbol = "R$"
end

usd = Currency.find_or_create_by!(code: "USD") do |c|
  c.name = "Dólar Americano"
  c.symbol = "$"
end

puts "== Seed: Criando taxas de câmbio padrão..."
# Taxa base: USD -> BRL = 5.0 (1 USD compra 5 BRL)
ExchangeRate.find_or_create_by!(
  from_currency: usd,
  to_currency: brl,
  reference_date: Date.today
) do |er|
  er.rate = 5.00000000
end

# Taxa reversa: BRL -> USD = 0.2 (1 BRL compra 0.2 USD)
ExchangeRate.find_or_create_by!(
  from_currency: brl,
  to_currency: usd,
  reference_date: Date.today
) do |er|
  er.rate = 0.20000000
end

puts "== Seed: Criando tipos de recebíveis com spreads base..."
# Duplicata Mercantil: Spread de 1.5% a.m. (0.0150)
ReceivableType.find_or_create_by!(code: "duplicata") do |rt|
  rt.name = "Duplicata Mercantil"
  rt.base_spread = 0.0150
end

# Cheque Pré-datado: Spread de 2.5% a.m. (0.0250)
ReceivableType.find_or_create_by!(code: "cheque") do |rt|
  rt.name = "Cheque Pré-datado"
  rt.base_spread = 0.0250
end

puts "== Seed: Concluído com sucesso!"

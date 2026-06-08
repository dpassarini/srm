require "test_helper"

class ApiV1Test < ActionDispatch::IntegrationTest
  setup do
    # Garante banco limpo e populado com os dados essenciais para o teste
    Receivable.delete_all
    Operation.delete_all
    ExchangeRate.delete_all
    ReceivableType.delete_all
    Currency.delete_all

    @brl = Currency.create!(code: "BRL", name: "Real", symbol: "R$")
    @usd = Currency.create!(code: "USD", name: "Dollar", symbol: "$")

    ExchangeRate.create!(from_currency: @usd, to_currency: @brl, rate: 5.0, reference_date: Date.today)
    ExchangeRate.create!(from_currency: @brl, to_currency: @usd, rate: 0.2, reference_date: Date.today)

    @duplicata = ReceivableType.create!(name: "Duplicata Mercantil", code: "duplicata", base_spread: 0.0150)
    @cheque = ReceivableType.create!(name: "Cheque Pré-datado", code: "cheque", base_spread: 0.0250)
  end

  test "retorna moedas cadastradas" do
    get api_v1_currencies_path
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    assert_equal ["BRL", "USD"], json.map { |c| c["code"] }.sort
  end

  test "retorna tipos de recebiveis cadastrados" do
    get api_v1_receivable_types_path
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    assert_equal ["cheque", "duplicata"], json.map { |rt| rt["code"] }.sort
  end

  test "cria nova taxa de cambio e gera taxa reversa correspondente" do
    post api_v1_exchange_rates_path, params: {
      exchange_rate: {
        from_currency_code: "USD",
        to_currency_code: "BRL",
        rate: 5.5,
        reference_date: (Date.today + 1.day).to_s
      }
    }

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 5.5, json["rate"].to_f

    # Verifica se a reversa foi gerada automaticamente para a mesma data
    reverse_rate = ExchangeRate.find_by(
      from_currency: @brl,
      to_currency: @usd,
      reference_date: Date.today + 1.day
    )
    assert_not_nil reverse_rate
    assert_equal (1.0 / 5.5).round(8), reverse_rate.rate.to_f
  end

  test "executa simulacao de lote sem salvar no banco" do
    receivables_payload = [
      { identifier: "DUP-001", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
      { identifier: "CHQ-001", face_value: 2000.00, due_date: (Date.today + 60.days).to_s, receivable_type_code: "cheque", currency_code: "BRL" }
    ]

    post simulate_api_v1_operations_path, params: {
      operation: {
        assignee: "Empresa XYZ",
        payment_currency_code: "USD",
        base_rate: 0.0,
        receivables: receivables_payload
      }
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Empresa XYZ", json["assignee"]
    assert_equal 3000.00, json["total_face_value"].to_f
    assert_equal 577.7701, json["total_net_value"].to_f # valor calculado em USD
    assert_equal 2, json["receivables_attributes"].length

    # Garante que nenhum registro foi criado no banco
    assert_equal 0, Operation.count
    assert_equal 0, Receivable.count
  end

  test "cria e liquida operacao atomicamente persistindo no banco" do
    receivables_payload = [
      { identifier: "DUP-002", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" }
    ]

    assert_difference -> { Operation.count } => 1, -> { Receivable.count } => 1 do
      post api_v1_operations_path, params: {
        operation: {
          assignee: "Empresa ABC",
          payment_currency_code: "BRL",
          base_rate: 0.0,
          receivables: receivables_payload
        }
      }
      assert_response :created
    end

    operation = Operation.last
    assert_equal "Empresa ABC", operation.assignee
    assert_equal 1000.00, operation.total_face_value.to_f
    assert_equal 985.2217, operation.total_net_value.to_f # 1000 / 1.015^1 = 985.2217

    receivable = operation.receivables.first
    assert_equal "DUP-002", receivable.identifier
    assert_equal 1000.00, receivable.face_value.to_f
    assert_equal 985.2217, receivable.net_value.to_f
  end

  test "falha na criacao e mantem atomicidade do banco se houver dados invalidos" do
    receivables_payload = [
      { identifier: "DUP-GOOD", face_value: 1000.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" },
      { identifier: "DUP-BAD", face_value: -500.00, due_date: (Date.today + 30.days).to_s, receivable_type_code: "duplicata", currency_code: "BRL" } # valor de face invalido
    ]

    assert_no_difference -> { Operation.count } do
      assert_no_difference -> { Receivable.count } do
        post api_v1_operations_path, params: {
          operation: {
            assignee: "Empresa Falha",
            payment_currency_code: "BRL",
            base_rate: 0.0,
            receivables: receivables_payload
          }
        }
        assert_response :unprocessable_entity
      end
    end
  end
end

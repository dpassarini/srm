import { useState, useEffect, useCallback } from "react";
import { 
  getCurrencies, 
  getReceivableTypes, 
  getExchangeRates, 
  createExchangeRate, 
  simulateOperation, 
  createOperation, 
  getOperations,
  type Currency,
  type ReceivableType,
  type ExchangeRate,
  type ReceivableInput,
  type CalculatedOperation,
  type OperationHistoryItem
} from "./services/api";
import { 
  Calculator, 
  History, 
  TrendingUp, 
  Plus, 
  Trash2, 
  DollarSign, 
  RefreshCw, 
  Search, 
  ArrowRight,
  CheckCircle,
  AlertTriangle,
  ChevronDown,
  ChevronUp,
  FileText
} from "lucide-react";

export default function App() {
  // Navigation
  const [activeTab, setActiveTab] = useState<"simulator" | "history" | "rates">("simulator");

  // Metadata from API
  const [currencies, setCurrencies] = useState<Currency[]>([]);
  const [receivableTypes, setReceivableTypes] = useState<ReceivableType[]>([]);
  const [exchangeRates, setExchangeRates] = useState<ExchangeRate[]>([]);

  // Simulation Form State
  const [assignee, setAssignee] = useState("");
  const [paymentCurrency, setPaymentCurrency] = useState("BRL");
  const [baseRate, setBaseRate] = useState(0.0);
  const [receivables, setReceivables] = useState<ReceivableInput[]>([
    { identifier: "TIT-01", face_value: 1000, due_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split("T")[0], receivable_type_code: "duplicata", currency_code: "BRL" }
  ]);
  const [simulationResult, setSimulationResult] = useState<CalculatedOperation | null>(null);

  // UI state
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // History Grid State
  const [historyOperations, setHistoryOperations] = useState<OperationHistoryItem[]>([]);
  const [expandedOperation, setExpandedOperation] = useState<number | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const [historyTotalPages, setHistoryTotalPages] = useState(1);
  const [historyTotalCount, setHistoryTotalCount] = useState(0);
  
  // History Filters
  const [filterAssignee, setFilterAssignee] = useState("");
  const [filterCurrency, setFilterCurrency] = useState("");
  const [filterStartDate, setFilterStartDate] = useState("");
  const [filterEndDate, setFilterEndDate] = useState("");

  // Exchange Rates Form State
  const [rateFrom, setRateFrom] = useState("USD");
  const [rateTo, setRateTo] = useState("BRL");
  const [rateValue, setRateValue] = useState(5.0);
  const [rateDate, setRateDate] = useState(new Date().toISOString().split("T")[0]);

  // Load Metadata
  const loadMetadata = async () => {
    try {
      const [currs, types, rates] = await Promise.all([
        getCurrencies(),
        getReceivableTypes(),
        getExchangeRates()
      ]);
      setCurrencies(currs);
      setReceivableTypes(types);
      setExchangeRates(rates);
      
      // Defaults if currencies loaded
      if (currs.length > 0 && !paymentCurrency) {
        setPaymentCurrency(currs[0].code);
      }
    } catch (err: any) {
      setErrorMsg("Erro ao carregar dados do servidor. Certifique-se de que o backend Rails está rodando.");
    }
  };

  useEffect(() => {
    loadMetadata();
  }, []);

  // Fetch History on Tab Active or page/filter change
  const fetchHistory = useCallback(async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const filters = {
        assignee: filterAssignee || undefined,
        payment_currency_code: filterCurrency || undefined,
        start_date: filterStartDate || undefined,
        end_date: filterEndDate || undefined,
      };
      const data = await getOperations(historyPage, 10, filters);
      setHistoryOperations(data.operations);
      setHistoryTotalPages(data.meta.total_pages);
      setHistoryTotalCount(data.meta.total_count);
    } catch (err: any) {
      setErrorMsg(err.response?.data?.error || "Erro ao buscar histórico de liquidações.");
    } finally {
      setLoading(false);
    }
  }, [historyPage, filterAssignee, filterCurrency, filterStartDate, filterEndDate]);

  useEffect(() => {
    if (activeTab === "history") {
      fetchHistory();
    }
  }, [activeTab, fetchHistory]);

  // Handle Simulation
  const triggerSimulation = async () => {
    if (!assignee) {
      setErrorMsg("Por favor, informe o nome do Cedente para simular.");
      return;
    }
    if (receivables.length === 0) {
      setErrorMsg("Adicione pelo menos um título para realizar a simulação.");
      return;
    }

    setLoading(true);
    setErrorMsg(null);
    try {
      const payload = {
        assignee,
        payment_currency_code: paymentCurrency,
        base_rate: baseRate / 100, // convert percentage (e.g. 1% -> 0.01)
        receivables: receivables.map(r => ({
          ...r,
          face_value: Number(r.face_value)
        }))
      };
      const result = await simulateOperation(payload);
      setSimulationResult(result);
    } catch (err: any) {
      setSimulationResult(null);
      setErrorMsg(err.response?.data?.error || "Erro ao executar simulação. Verifique as taxas de câmbio ou as datas.");
    } finally {
      setLoading(false);
    }
  };

  // Perform Liquidation (ACID save)
  const triggerLiquidation = async () => {
    if (!assignee) {
      setErrorMsg("Nome do Cedente é obrigatório.");
      return;
    }
    if (receivables.length === 0) {
      setErrorMsg("Adicione pelo menos um título.");
      return;
    }

    setLoading(true);
    setErrorMsg(null);
    setSuccessMsg(null);
    try {
      const payload = {
        assignee,
        payment_currency_code: paymentCurrency,
        base_rate: baseRate / 100,
        receivables: receivables.map(r => ({
          ...r,
          face_value: Number(r.face_value)
        }))
      };
      await createOperation(payload);
      setSuccessMsg("Operação de Cessão liquidada e gravada com sucesso!");
      
      // Reset Form
      setAssignee("");
      setReceivables([
        { identifier: "TIT-01", face_value: 1000, due_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split("T")[0], receivable_type_code: "duplicata", currency_code: "BRL" }
      ]);
      setSimulationResult(null);
      
      // Refresh rates/history in background
      loadMetadata();
    } catch (err: any) {
      const details = err.response?.data?.details;
      const errorText = details ? `${err.response.data.error}: ${details.join(", ")}` : err.response?.data?.error;
      setErrorMsg(errorText || "Erro ao liquidar operação.");
    } finally {
      setLoading(false);
    }
  };

  // Handle Exchange Rate Creation
  const handleCreateRate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rateFrom === rateTo) {
      setErrorMsg("Moeda de origem e destino devem ser diferentes.");
      return;
    }
    if (rateValue <= 0) {
      setErrorMsg("A taxa cambial deve ser maior que zero.");
      return;
    }

    setLoading(true);
    setErrorMsg(null);
    setSuccessMsg(null);
    try {
      await createExchangeRate(rateFrom, rateTo, rateValue, rateDate);
      setSuccessMsg(`Taxa cambial registrada com sucesso!`);
      // Reload rates list
      const rates = await getExchangeRates();
      setExchangeRates(rates);
    } catch (err: any) {
      setErrorMsg(err.response?.data?.error || "Erro ao registrar taxa cambial.");
    } finally {
      setLoading(false);
    }
  };

  // Dynamically manage receivables rows
  const addReceivableRow = () => {
    const nextIndex = receivables.length + 1;
    setReceivables([
      ...receivables,
      {
        identifier: `TIT-0${nextIndex}`,
        face_value: 1000,
        due_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split("T")[0],
        receivable_type_code: "duplicata",
        currency_code: paymentCurrency
      }
    ]);
  };

  const removeReceivableRow = (index: number) => {
    const updated = [...receivables];
    updated.splice(index, 1);
    setReceivables(updated);
  };

  const updateReceivableRow = (index: number, field: keyof ReceivableInput, value: any) => {
    const updated = [...receivables];
    updated[index] = {
      ...updated[index],
      [field]: value
    };
    setReceivables(updated);
  };

  // Auto-run simulation on relevant field changes (with a small delay / UX check)
  useEffect(() => {
    if (assignee && receivables.length > 0 && receivables.every(r => r.identifier && r.face_value > 0 && r.due_date)) {
      const delayDebounce = setTimeout(() => {
        triggerSimulation();
      }, 600); // 600ms debounce
      return () => clearTimeout(delayDebounce);
    }
  }, [assignee, paymentCurrency, baseRate, receivables]);

  // Utility to format values
  const formatMoney = (val: number, currencyCode: string) => {
    const symbol = currencies.find(c => c.code === currencyCode)?.symbol || "";
    return `${symbol} ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 4 })}`;
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-8 md:py-12">
      {/* Header */}
      <header className="flex flex-col md:flex-row justify-between items-center mb-10 pb-6 border-b border-slate-800/60 gap-6">
        <div className="flex items-center gap-4">
          <div className="bg-gradient-to-tr from-blue-600 to-purple-600 p-3 rounded-2xl shadow-lg shadow-blue-500/20">
            <Calculator className="h-8 w-8 text-white" />
          </div>
          <div>
            <h1 className="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-400 via-indigo-200 to-purple-400 bg-clip-text text-transparent">
              SRM Credit Engine
            </h1>
            <p className="text-xs text-slate-400 mt-1">Plataforma de Cessão de Crédito Multimoedas</p>
          </div>
        </div>

        {/* Currency Rates Ticker */}
        <div className="flex gap-4 overflow-x-auto py-2 px-4 glass-panel rounded-2xl max-w-full">
          <div className="text-xs font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-2 border-r border-slate-800 pr-4 shrink-0">
            <TrendingUp className="h-4 w-4 text-emerald-400" />
            Câmbio Atual:
          </div>
          {exchangeRates.slice(0, 2).map(rate => (
            <div key={rate.id} className="flex items-center gap-2 text-sm text-slate-200 shrink-0 font-mono">
              <span className="font-bold text-slate-400">{rate.from_currency.code}</span>
              <ArrowRight className="h-3 w-3 text-slate-500" />
              <span className="font-bold text-blue-400">{rate.to_currency.code}</span>
              <span className="bg-slate-800/80 px-2 py-0.5 rounded text-xs text-slate-300 font-bold border border-slate-700/50">
                {Number(rate.rate).toFixed(4)}
              </span>
            </div>
          ))}
          {exchangeRates.length === 0 && (
            <span className="text-xs text-yellow-500/80 flex items-center gap-1 font-mono">
              Nenhuma taxa registrada hoje
            </span>
          )}
        </div>
      </header>

      {/* Messages */}
      {errorMsg && (
        <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-200 flex items-start gap-3 animate-pulse">
          <AlertTriangle className="h-5 w-5 text-red-400 shrink-0 mt-0.5" />
          <div>
            <h4 className="font-bold text-sm">Ocorreu um erro</h4>
            <p className="text-xs text-red-300/90 mt-0.5">{errorMsg}</p>
          </div>
        </div>
      )}

      {successMsg && (
        <div className="mb-6 p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-200 flex items-start gap-3">
          <CheckCircle className="h-5 w-5 text-emerald-400 shrink-0 mt-0.5" />
          <div>
            <h4 className="font-bold text-sm">Sucesso!</h4>
            <p className="text-xs text-emerald-300/90 mt-0.5">{successMsg}</p>
          </div>
        </div>
      )}

      {/* Tabs Menu */}
      <nav className="flex gap-2 mb-8 bg-slate-900/60 p-1 rounded-xl border border-slate-800/80 max-w-md">
        <button
          onClick={() => { setActiveTab("simulator"); setErrorMsg(null); setSuccessMsg(null); }}
          className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-4 rounded-lg text-sm font-semibold transition-all duration-200 ${
            activeTab === "simulator" 
              ? "bg-blue-600 text-white shadow-md shadow-blue-500/10" 
              : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
          }`}
        >
          <Calculator className="h-4 w-4" />
          Simulador
        </button>
        <button
          onClick={() => { setActiveTab("history"); setErrorMsg(null); setSuccessMsg(null); setHistoryPage(1); }}
          className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-4 rounded-lg text-sm font-semibold transition-all duration-200 ${
            activeTab === "history" 
              ? "bg-blue-600 text-white shadow-md shadow-blue-500/10" 
              : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
          }`}
        >
          <History className="h-4 w-4" />
          Histórico
        </button>
        <button
          onClick={() => { setActiveTab("rates"); setErrorMsg(null); setSuccessMsg(null); }}
          className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-4 rounded-lg text-sm font-semibold transition-all duration-200 ${
            activeTab === "rates" 
              ? "bg-blue-600 text-white shadow-md shadow-blue-500/10" 
              : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
          }`}
        >
          <TrendingUp className="h-4 w-4" />
          Câmbio
        </button>
      </nav>

      {/* Tab Contents */}
      <main>
        {/* Simulator View */}
        {activeTab === "simulator" && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
            {/* Input Form Column */}
            <div className="lg:col-span-2 space-y-6">
              {/* Operation Details Card */}
              <div className="glass-panel glass-panel-glow rounded-3xl p-6 md:p-8 space-y-6">
                <h3 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                  <FileText className="h-5 w-5 text-blue-400" />
                  Dados Gerais da Cessão
                </h3>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Cedente</label>
                    <input
                      type="text"
                      placeholder="Nome da empresa cedente"
                      value={assignee}
                      onChange={e => setAssignee(e.target.value)}
                      className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-xl px-4 py-2.5 text-sm text-slate-100 placeholder-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-all font-semibold"
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Moeda de Liquidação</label>
                    <select
                      value={paymentCurrency}
                      onChange={e => setPaymentCurrency(e.target.value)}
                      className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-xl px-4 py-2.5 text-sm text-slate-100 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-all font-semibold cursor-pointer"
                    >
                      {currencies.map(c => (
                        <option key={c.id} value={c.code}>{c.code} ({c.symbol})</option>
                      ))}
                    </select>
                  </div>

                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider flex justify-between">
                      <span>Taxa Base (% a.m.)</span>
                      <span className="text-blue-400">ex: CDI/Selic</span>
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        placeholder="0.00"
                        value={baseRate || ""}
                        onChange={e => setBaseRate(Number(e.target.value))}
                        className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-xl pl-4 pr-8 py-2.5 text-sm text-slate-100 placeholder-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-all font-mono font-semibold"
                      />
                      <span className="absolute right-4 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-500">%</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Títulos Table Card */}
              <div className="glass-panel glass-panel-glow rounded-3xl p-6 md:p-8 space-y-6">
                <div className="flex justify-between items-center">
                  <h3 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                    <DollarSign className="h-5 w-5 text-purple-400" />
                    Recebíveis do Lote
                  </h3>
                  <button
                    onClick={addReceivableRow}
                    className="flex items-center gap-1.5 bg-blue-600/10 hover:bg-blue-600 text-blue-400 hover:text-white border border-blue-500/20 hover:border-transparent rounded-xl px-3 py-1.5 text-xs font-bold transition-all duration-200"
                  >
                    <Plus className="h-4 w-4" />
                    Adicionar Título
                  </button>
                </div>

                {/* Grid Header and Rows */}
                <div className="space-y-4 max-h-[420px] overflow-y-auto pr-1">
                  {receivables.map((rec, index) => (
                    <div key={index} className="grid grid-cols-1 md:grid-cols-12 gap-4 bg-slate-900/35 border border-slate-800/80 p-4 rounded-2xl items-center relative group">
                      {/* Identifier input */}
                      <div className="md:col-span-2 space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase md:hidden">ID</label>
                        <input
                          type="text"
                          placeholder="ID"
                          value={rec.identifier}
                          onChange={e => updateReceivableRow(index, "identifier", e.target.value)}
                          className="w-full bg-slate-900 border border-slate-800/60 focus:border-blue-500 rounded-lg px-2.5 py-1.5 text-xs text-slate-200 font-semibold focus:outline-none"
                        />
                      </div>

                      {/* Receivable Type */}
                      <div className="md:col-span-2 space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase md:hidden">Tipo</label>
                        <select
                          value={rec.receivable_type_code}
                          onChange={e => updateReceivableRow(index, "receivable_type_code", e.target.value)}
                          className="w-full bg-slate-900 border border-slate-800/60 focus:border-blue-500 rounded-lg px-2 py-1.5 text-xs text-slate-200 font-semibold focus:outline-none cursor-pointer"
                        >
                          {receivableTypes.map(t => (
                            <option key={t.id} value={t.code}>{t.name} ({(Number(t.base_spread) * 100).toFixed(1)}%)</option>
                          ))}
                        </select>
                      </div>

                      {/* Currency original */}
                      <div className="md:col-span-2 space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase md:hidden">Moeda Título</label>
                        <select
                          value={rec.currency_code}
                          onChange={e => updateReceivableRow(index, "currency_code", e.target.value)}
                          className="w-full bg-slate-900 border border-slate-800/60 focus:border-blue-500 rounded-lg px-2 py-1.5 text-xs text-slate-200 font-semibold focus:outline-none cursor-pointer"
                        >
                          {currencies.map(c => (
                            <option key={c.id} value={c.code}>{c.code}</option>
                          ))}
                        </select>
                      </div>

                      {/* Face Value */}
                      <div className="md:col-span-3 space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase md:hidden">Valor Face</label>
                        <div className="relative">
                          <input
                            type="number"
                            placeholder="0.00"
                            value={rec.face_value || ""}
                            onChange={e => updateReceivableRow(index, "face_value", Number(e.target.value))}
                            className="w-full bg-slate-900 border border-slate-800/60 focus:border-blue-500 rounded-lg pl-7 pr-2 py-1.5 text-xs text-slate-200 font-mono font-semibold focus:outline-none"
                          />
                          <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-[10px] font-bold text-slate-500">
                            {currencies.find(c => c.code === rec.currency_code)?.symbol || ""}
                          </span>
                        </div>
                      </div>

                      {/* Due date */}
                      <div className="md:col-span-2.5 space-y-1 flex items-center gap-2">
                        <div className="flex-1">
                          <label className="text-[10px] font-bold text-slate-500 uppercase md:hidden">Vencimento</label>
                          <input
                            type="date"
                            value={rec.due_date}
                            onChange={e => updateReceivableRow(index, "due_date", e.target.value)}
                            className="w-full bg-slate-900 border border-slate-800/60 focus:border-blue-500 rounded-lg px-2 py-1 text-xs text-slate-200 focus:outline-none cursor-pointer"
                          />
                        </div>
                        {receivables.length > 1 && (
                          <button
                            onClick={() => removeReceivableRow(index)}
                            className="text-slate-500 hover:text-red-400 p-1.5 rounded-lg hover:bg-slate-800/40 transition-colors mt-0.5 md:mt-0"
                            title="Remover título"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Results Sidebar Column */}
            <div className="space-y-6">
              {/* Summary Dashboard Card */}
              <div className="glass-panel glass-panel-glow rounded-3xl p-6 md:p-8 space-y-6">
                <div className="flex justify-between items-center">
                  <h3 className="text-lg font-bold text-slate-100">Resultado da Simulação</h3>
                  {loading && (
                    <RefreshCw className="h-4 w-4 text-blue-400 animate-spin" />
                  )}
                </div>

                {simulationResult ? (
                  <div className="space-y-6">
                    {/* Big Liquid Value */}
                    <div className="bg-gradient-to-br from-blue-950/45 to-slate-950/45 border border-blue-500/15 p-5 rounded-2xl text-center space-y-1 shadow-inner">
                      <span className="text-[10px] font-bold text-blue-400 uppercase tracking-widest block">
                        Valor Líquido da Operação
                      </span>
                      <span className="text-3xl font-extrabold text-blue-300 font-mono tracking-tight block">
                        {formatMoney(simulationResult.total_net_value, paymentCurrency)}
                      </span>
                      <span className="text-xs text-slate-500 font-medium block">
                        Valor de Face Total: {formatMoney(simulationResult.total_face_value, paymentCurrency)}
                      </span>
                    </div>

                    {/* Deságio detail */}
                    <div className="space-y-2">
                      <div className="flex justify-between text-xs text-slate-400 font-medium">
                        <span>Deságio Aplicado (Desconto):</span>
                        <span className="font-mono text-red-400 font-bold">
                          {formatMoney(simulationResult.total_face_value - simulationResult.total_net_value, paymentCurrency)}
                        </span>
                      </div>
                      <div className="flex justify-between text-xs text-slate-400 font-medium">
                        <span>Quantidade de Títulos:</span>
                        <span className="text-slate-200 font-bold">{simulationResult.receivables_attributes.length}</span>
                      </div>
                      <div className="flex justify-between text-xs text-slate-400 font-medium">
                        <span>Taxa Base de Operação:</span>
                        <span className="text-slate-200 font-bold font-mono">{baseRate.toFixed(2)}% a.m.</span>
                      </div>
                    </div>

                    <div className="border-t border-slate-800/80 pt-4 space-y-3">
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block">
                        Detalhamento por Título
                      </span>
                      
                      <div className="space-y-2 max-h-[220px] overflow-y-auto pr-1">
                        {simulationResult.receivables_attributes.map((rec, i) => {
                          const typeCode = receivableTypes.find(t => t.id === rec.receivable_type_id)?.code;
                          const symbol = currencies.find(c => c.id === rec.currency_id)?.symbol || "";
                          
                          return (
                            <div key={i} className="flex justify-between items-center text-xs bg-slate-950/20 border border-slate-900/60 p-2.5 rounded-xl font-mono">
                              <div>
                                <span className="font-bold text-slate-200 block">{rec.identifier}</span>
                                <span className="text-[10px] text-slate-500 block uppercase font-sans mt-0.5">
                                  {typeCode} • {rec.days_to_maturity} dias
                                </span>
                              </div>
                              <div className="text-right">
                                <span className="text-slate-300 font-bold block">
                                  {symbol} {rec.net_value_original.toFixed(2)}
                                </span>
                                {rec.exchange_rate_applied && (
                                  <span className="text-[10px] text-blue-400 block font-sans">
                                    câmbio: {Number(rec.exchange_rate_applied).toFixed(4)}
                                  </span>
                                )}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    {/* Liquidate button */}
                    <button
                      onClick={triggerLiquidation}
                      disabled={loading}
                      className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold py-3.5 px-6 rounded-2xl shadow-lg shadow-blue-500/20 hover:shadow-blue-500/35 hover:-translate-y-0.5 disabled:opacity-50 disabled:pointer-events-none active:translate-y-0 transition-all duration-200 text-sm flex items-center justify-center gap-2 cursor-pointer mt-4"
                    >
                      <CheckCircle className="h-5 w-5" />
                      Liquidar Operação no Fundo
                    </button>
                  </div>
                ) : (
                  <div className="text-center py-12 text-slate-500 space-y-3 bg-slate-950/10 rounded-2xl border border-dashed border-slate-800/80">
                    <Calculator className="h-10 w-10 text-slate-600 mx-auto" />
                    <div>
                      <p className="text-xs font-semibold text-slate-400">Aguardando dados</p>
                      <p className="text-[10px] text-slate-600 mt-1 max-w-[200px] mx-auto">
                        Preencha o Cedente e adicione títulos para visualizar a simulação.
                      </p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* History View */}
        {activeTab === "history" && (
          <div className="space-y-6">
            {/* Filter Panel */}
            <div className="glass-panel glass-panel-glow rounded-3xl p-6 space-y-4">
              <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                <Search className="h-4 w-4 text-blue-400" />
                Filtros Analíticos
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Cedente</label>
                  <input
                    type="text"
                    placeholder="Filtrar por cedente"
                    value={filterAssignee}
                    onChange={e => { setFilterAssignee(e.target.value); setHistoryPage(1); }}
                    className="w-full bg-slate-900/60 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-200 focus:outline-none"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Moeda de Pagamento</label>
                  <select
                    value={filterCurrency}
                    onChange={e => { setFilterCurrency(e.target.value); setHistoryPage(1); }}
                    className="w-full bg-slate-900/60 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-200 focus:outline-none cursor-pointer"
                  >
                    <option value="">Todas</option>
                    {currencies.map(c => (
                      <option key={c.id} value={c.code}>{c.code}</option>
                    ))}
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Data Início</label>
                  <input
                    type="date"
                    value={filterStartDate}
                    onChange={e => { setFilterStartDate(e.target.value); setHistoryPage(1); }}
                    className="w-full bg-slate-900/60 border border-slate-800 rounded-lg px-3 py-1 text-xs text-slate-200 focus:outline-none cursor-pointer"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Data Fim</label>
                  <input
                    type="date"
                    value={filterEndDate}
                    onChange={e => { setFilterEndDate(e.target.value); setHistoryPage(1); }}
                    className="w-full bg-slate-900/60 border border-slate-800 rounded-lg px-3 py-1 text-xs text-slate-200 focus:outline-none cursor-pointer"
                  />
                </div>
              </div>
            </div>

            {/* Operations History Grid */}
            <div className="glass-panel glass-panel-glow rounded-3xl overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-slate-800 bg-slate-900/40 text-xs font-bold text-slate-400 uppercase tracking-wider">
                      <th className="py-4 px-6">Cedente</th>
                      <th className="py-4 px-6">Data Liquidação</th>
                      <th className="py-4 px-6 text-right">Moeda Pago</th>
                      <th className="py-4 px-6 text-right">Valor Face Total</th>
                      <th className="py-4 px-6 text-right">Valor Líquido Total</th>
                      <th className="py-4 px-6 text-center">Títulos</th>
                    </tr>
                  </thead>
                  <tbody>
                    {historyOperations.map(op => {
                      const isExpanded = expandedOperation === op.id;
                      return (
                        <>
                          <tr 
                            key={op.id} 
                            onClick={() => setExpandedOperation(isExpanded ? null : op.id)}
                            className="border-b border-slate-800/60 hover:bg-slate-900/30 transition-all cursor-pointer text-sm font-medium"
                          >
                            <td className="py-4 px-6 text-slate-200 font-bold">{op.assignee}</td>
                            <td className="py-4 px-6 text-slate-400">
                              {new Date(op.created_at).toLocaleString("pt-BR")}
                            </td>
                            <td className="py-4 px-6 text-right font-mono font-bold text-blue-400">
                              {op.payment_currency.code}
                            </td>
                            <td className="py-4 px-6 text-right font-mono text-slate-300">
                              {formatMoney(Number(op.total_face_value), op.payment_currency.code)}
                            </td>
                            <td className="py-4 px-6 text-right font-mono text-emerald-400 font-bold">
                              {formatMoney(Number(op.total_net_value), op.payment_currency.code)}
                            </td>
                            <td className="py-4 px-6 text-center">
                              <button className="text-slate-500 hover:text-blue-400 inline-flex items-center gap-1.5 text-xs font-bold bg-slate-900/80 px-3 py-1 rounded-lg border border-slate-800">
                                {op.receivables.length}
                                {isExpanded ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
                              </button>
                            </td>
                          </tr>
                          
                          {/* Expanded detail row */}
                          {isExpanded && (
                            <tr className="bg-slate-950/40 border-b border-slate-800">
                              <td colSpan={6} className="py-4 px-6">
                                <div className="rounded-xl border border-slate-800/80 overflow-hidden bg-slate-900/20">
                                  <table className="w-full text-left border-collapse text-xs font-mono">
                                    <thead>
                                      <tr className="bg-slate-950/30 border-b border-slate-800/50 text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                                        <th className="py-2.5 px-4">Identificador</th>
                                        <th className="py-2.5 px-4">Tipo</th>
                                        <th className="py-2.5 px-4 text-center">Vencimento (Dias)</th>
                                        <th className="py-2.5 px-4 text-right">Moeda Original</th>
                                        <th className="py-2.5 px-4 text-right">Valor Face</th>
                                        <th className="py-2.5 px-4 text-right">Valor Líquido (VP)</th>
                                        <th className="py-2.5 px-4 text-right">Taxa Câmbio</th>
                                      </tr>
                                    </thead>
                                    <tbody>
                                      {op.receivables.map(rec => (
                                        <tr key={rec.id} className="border-b border-slate-900/40 hover:bg-slate-900/50 transition-colors">
                                          <td className="py-2 px-4 text-slate-200 font-bold">{rec.identifier}</td>
                                          <td className="py-2 px-4 text-slate-400 font-sans">{rec.receivable_type.name}</td>
                                          <td className="py-2 px-4 text-center text-slate-300">
                                            {rec.due_date} ({rec.days_to_maturity}d)
                                          </td>
                                          <td className="py-2 px-4 text-right text-slate-400 font-bold">{rec.currency.code}</td>
                                          <td className="py-2 px-4 text-right text-slate-300">
                                            {formatMoney(Number(rec.face_value), rec.currency.code)}
                                          </td>
                                          <td className="py-2 px-4 text-right text-emerald-400 font-bold">
                                            {formatMoney(Number(rec.net_value), op.payment_currency.code)}
                                          </td>
                                          <td className="py-2 px-4 text-right text-blue-400">
                                            {rec.exchange_rate_applied ? Number(rec.exchange_rate_applied).toFixed(4) : "—"}
                                          </td>
                                        </tr>
                                      ))}
                                    </tbody>
                                  </table>
                                </div>
                              </td>
                            </tr>
                          )}
                        </>
                      );
                    })}

                    {historyOperations.length === 0 && (
                      <tr>
                        <td colSpan={6} className="py-12 text-center text-slate-500 font-medium space-y-2">
                          <History className="h-10 w-10 text-slate-600 mx-auto" />
                          <p className="text-sm">Nenhuma cessão de crédito liquidada encontrada.</p>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>

              {/* Pagination controls */}
              {historyTotalPages > 1 && (
                <div className="flex justify-between items-center px-6 py-4 bg-slate-900/20 border-t border-slate-800/60 text-xs">
                  <span className="text-slate-400">
                    Mostrando <strong className="text-slate-200">{historyOperations.length}</strong> de{" "}
                    <strong className="text-slate-200">{historyTotalCount}</strong> operações
                  </span>

                  <div className="flex gap-2">
                    <button
                      onClick={() => setHistoryPage(prev => Math.max(prev - 1, 1))}
                      disabled={historyPage === 1}
                      className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-900/80 text-slate-400 hover:text-slate-200 disabled:opacity-30 disabled:pointer-events-none transition-colors cursor-pointer font-bold"
                    >
                      Anterior
                    </button>
                    <span className="flex items-center px-3 text-slate-400">
                      Página {historyPage} de {historyTotalPages}
                    </span>
                    <button
                      onClick={() => setHistoryPage(prev => Math.min(prev + 1, historyTotalPages))}
                      disabled={historyPage === historyTotalPages}
                      className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-900/80 text-slate-400 hover:text-slate-200 disabled:opacity-30 disabled:pointer-events-none transition-colors cursor-pointer font-bold"
                    >
                      Próxima
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Câmbio View */}
        {activeTab === "rates" && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
            {/* Create rate column */}
            <div className="glass-panel glass-panel-glow rounded-3xl p-6 md:p-8 space-y-6">
              <h3 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                <TrendingUp className="h-5 w-5 text-blue-400" />
                Registrar Nova Taxa
              </h3>

              <form onSubmit={handleCreateRate} className="space-y-5">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1">
                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Origem</label>
                    <select
                      value={rateFrom}
                      onChange={e => setRateFrom(e.target.value)}
                      className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-lg px-3 py-2 text-xs text-slate-100 focus:outline-none cursor-pointer font-semibold"
                    >
                      {currencies.map(c => (
                        <option key={c.id} value={c.code}>{c.code}</option>
                      ))}
                    </select>
                  </div>
                  <div className="space-y-1">
                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Destino</label>
                    <select
                      value={rateTo}
                      onChange={e => setRateTo(e.target.value)}
                      className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-lg px-3 py-2 text-xs text-slate-100 focus:outline-none cursor-pointer font-semibold"
                    >
                      {currencies.map(c => (
                        <option key={c.id} value={c.code}>{c.code}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Cotação (Taxa)</label>
                  <input
                    type="number"
                    step="0.00000001"
                    min="0.00000001"
                    placeholder="1.00000000"
                    value={rateValue || ""}
                    onChange={e => setRateValue(Number(e.target.value))}
                    className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-lg px-3 py-2 text-xs text-slate-100 font-mono focus:outline-none"
                    required
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Data de Referência</label>
                  <input
                    type="date"
                    value={rateDate}
                    onChange={e => setRateDate(e.target.value)}
                    className="w-full bg-slate-900/90 border border-slate-800 focus:border-blue-500 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none cursor-pointer"
                    required
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-2.5 px-4 rounded-xl shadow-md shadow-blue-500/10 transition-colors duration-200 text-xs flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Plus className="h-4 w-4" />
                  Salvar Cotação
                </button>
              </form>
            </div>

            {/* Rates list column */}
            <div className="lg:col-span-2 glass-panel glass-panel-glow rounded-3xl p-6 md:p-8 space-y-4">
              <h3 className="text-lg font-bold text-slate-100">Cotações Recentes</h3>
              
              <div className="border border-slate-850 rounded-2xl overflow-hidden bg-slate-950/20">
                <div className="overflow-x-auto max-h-[380px] overflow-y-auto">
                  <table className="w-full text-left border-collapse text-xs font-mono">
                    <thead>
                      <tr className="bg-slate-900/40 border-b border-slate-800 text-[10px] font-bold text-slate-400 uppercase tracking-wider font-sans">
                        <th className="py-3 px-4">De</th>
                        <th className="py-3 px-4">Para</th>
                        <th className="py-3 px-4 text-right">Taxa Cambial</th>
                        <th className="py-3 px-4">Data Referência</th>
                      </tr>
                    </thead>
                    <tbody>
                      {exchangeRates.map(rate => (
                        <tr key={rate.id} className="border-b border-slate-900/40 hover:bg-slate-900/20 transition-colors">
                          <td className="py-2.5 px-4 text-slate-300 font-bold">{rate.from_currency.code}</td>
                          <td className="py-2.5 px-4 text-slate-300 font-bold">{rate.to_currency.code}</td>
                          <td className="py-2.5 px-4 text-right text-blue-400 font-bold">
                            {Number(rate.rate).toFixed(8)}
                          </td>
                          <td className="py-2.5 px-4 text-slate-400">{rate.reference_date}</td>
                        </tr>
                      ))}

                      {exchangeRates.length === 0 && (
                        <tr>
                          <td colSpan={4} className="py-8 text-center text-slate-600 font-medium font-sans">
                            Nenhuma taxa cambial registrada.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

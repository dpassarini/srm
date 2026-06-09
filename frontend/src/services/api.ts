import axios from "axios";

// Target the Rails 8 API running on port 3000
const API_URL = import.meta.env.VITE_API_URL || "http://localhost:3000/api/v1";

export const api = axios.create({
  baseURL: API_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

export interface Currency {
  id: number;
  code: string;
  name: string;
  symbol: string;
}

export interface ReceivableType {
  id: number;
  name: string;
  code: string;
  base_spread: string; // returns as decimal string from API
}

export interface ExchangeRate {
  id: number;
  rate: string;
  reference_date: string;
  from_currency: {
    code: string;
    symbol: string;
  };
  to_currency: {
    code: string;
    symbol: string;
  };
}

export interface ReceivableInput {
  identifier: string;
  face_value: number;
  due_date: string;
  receivable_type_code: string;
  currency_code: string;
}

export interface OperationSimulatePayload {
  assignee: string;
  payment_currency_code: string;
  base_rate: number;
  receivables: ReceivableInput[];
}

export interface CalculatedReceivable {
  identifier: string;
  face_value: number;
  net_value_original: number;
  net_value: number;
  due_date: string;
  days_to_maturity: number;
  spread_applied: number;
  base_rate_applied: number;
  exchange_rate_applied: number | null;
  receivable_type_id: number;
  currency_id: number;
}

export interface CalculatedOperation {
  assignee: string;
  payment_currency_id: number;
  total_face_value: number;
  total_net_value: number;
  receivables_attributes: CalculatedReceivable[];
}

export interface OperationHistoryItem {
  id: number;
  assignee: string;
  total_face_value: string;
  total_net_value: string;
  status: string;
  created_at: string;
  payment_currency: {
    code: string;
    symbol: string;
  };
  receivables: Array<{
    id: number;
    identifier: string;
    face_value: string;
    net_value: string;
    due_date: string;
    days_to_maturity: number;
    spread_applied: string;
    base_rate_applied: string;
    exchange_rate_applied: string | null;
    currency: {
      code: string;
      symbol: string;
    };
    receivable_type: {
      code: string;
      name: string;
    };
  }>;
}

export interface OperationHistoryResponse {
  operations: OperationHistoryItem[];
  meta: {
    current_page: number;
    per_page: number;
    total_pages: number;
    total_count: number;
  };
}

export const getCurrencies = async (): Promise<Currency[]> => {
  const response = await api.get<Currency[]>("/currencies");
  return response.data;
};

export const getReceivableTypes = async (): Promise<ReceivableType[]> => {
  const response = await api.get<ReceivableType[]>("/receivable_types");
  return response.data;
};

export const getExchangeRates = async (): Promise<ExchangeRate[]> => {
  const response = await api.get<ExchangeRate[]>("/exchange_rates");
  return response.data;
};

export const createExchangeRate = async (
  fromCode: string,
  toCode: string,
  rate: number,
  referenceDate?: string
): Promise<any> => {
  const response = await api.post("/exchange_rates", {
    exchange_rate: {
      from_currency_code: fromCode,
      to_currency_code: toCode,
      rate,
      reference_date: referenceDate,
    },
  });
  return response.data;
};

export const simulateOperation = async (
  payload: OperationSimulatePayload
): Promise<CalculatedOperation> => {
  const response = await api.post<CalculatedOperation>("/operations/simulate", {
    operation: payload,
  });
  return response.data;
};

export const createOperation = async (
  payload: OperationSimulatePayload
): Promise<OperationHistoryItem> => {
  const response = await api.post<OperationHistoryItem>("/operations", {
    operation: payload,
  });
  return response.data;
};

export const getOperations = async (
  page = 1,
  perPage = 10,
  filters: {
    assignee?: string;
    payment_currency_code?: string;
    start_date?: string;
    end_date?: string;
  } = {}
): Promise<OperationHistoryResponse> => {
  const response = await api.get<OperationHistoryResponse>("/operations", {
    params: {
      page,
      per_page: perPage,
      ...filters,
    },
  });
  return response.data;
};

export interface SettlementReportInput {
  assignee_filter?: string;
  payment_currency_code_filter?: string;
  start_date_filter?: string;
  end_date_filter?: string;
}

export interface SettlementReport {
  id: number;
  assignee_filter: string | null;
  payment_currency_code_filter: string | null;
  start_date_filter: string | null;
  end_date_filter: string | null;
  status: string;
  file_name: string;
  created_at: string;
  updated_at: string;
}

export const getSettlementReports = async (): Promise<SettlementReport[]> => {
  const response = await api.get<SettlementReport[]>("/settlement_reports");
  return response.data;
};

export const createSettlementReport = async (
  payload: SettlementReportInput
): Promise<SettlementReport> => {
  const response = await api.post<SettlementReport>("/settlement_reports", {
    settlement_report: payload,
  });
  return response.data;
};

export const getReportDownloadUrl = (reportId: number): string => {
  return `${api.defaults.baseURL}/settlement_reports/${reportId}/download`;
};

export const getSwaggerUrl = (): string => {
  return (api.defaults.baseURL || API_URL).replace("/api/v1", "/swagger/index.html");
};

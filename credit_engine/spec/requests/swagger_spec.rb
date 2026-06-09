require "rails_helper"

RSpec.describe "Swagger Documentation API", type: :request do
  describe "GET /swagger" do
    it "retorna a interface do Swagger UI" do
      get "/swagger"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /api-docs" do
    it "redireciona para o swagger" do
      get "/api-docs"
      expect(response).to redirect_to("/swagger/index.html")
    end
  end
end

module Api
  module V1
    class ReceivableTypesController < BaseController
      def index
        types = ReceivableType.all.order(:name)
        render json: types, only: [ :id, :name, :code, :base_spread ]
      end
    end
  end
end

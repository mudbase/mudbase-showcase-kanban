# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `cards` - read granted to all three roles, create/edit/delete/move
  # owner+member per the RBAC matrix in plan/build-plan.md (`viewer` is read-only). All calls
  # force `debug_return_type: "Object"` (see ClientFactory) so every real document field
  # (`listId`, `title`, `position`, `assigneeId`, ...) survives typed deserialization.
  module CardsRepo
    # Real platform ceiling on the generated SDK's `DataApi#list_data` (`limit <= 100`,
    # confirmed live by the sibling social port's own build) - plenty for a demo-scale board.
    LIST_LIMIT = 100

    # @return [Array<Hash>] every card on the board, ascending by `position` - grouped
    #   client-side by `listId` (one query for the whole board, not one per column).
    def self.for_board(access_token:, board_id:)
      opts = { filter: { boardId: board_id }.to_json, sort: "position", limit: LIST_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.cards_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.cards_collection_id,
        id,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    rescue MudbaseSDK::ApiError => e
      raise e unless Mudbase::ApiFailure.from(e).status == 404

      nil
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.cards_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.cards_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.delete!(access_token:, id:)
      Mudbase::ClientFactory.data_api(access_token: access_token).delete_data(
        Mudbase::Config.project_id,
        Mudbase::Config.cards_collection_id,
        id,
      )
    end
  end
end

# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `lists` (the board's columns) - read granted to all three roles
  # (owner/member/viewer), create/rename/delete/reorder owner-only per the RBAC matrix in
  # plan/build-plan.md. Mudbase's own collection permissions are the real enforcement boundary;
  # this app's routes additionally gate on the signed-in user's `customRole` for defense in
  # depth (see `app/routes/lists_routes.rb`). All calls force `debug_return_type: "Object"` (see
  # ClientFactory) so every real document field survives typed deserialization.
  module ListsRepo
    # The generated SDK's `DataApi#list_data` client-side-validates `limit <= 100` - a real
    # platform-enforced ceiling (confirmed live by the sibling social port's own build), not
    # just a demo-scale choice. A single board never has anywhere near 100 columns in practice.
    LIST_LIMIT = 100

    # @return [Array<Hash>] every list on the board, ascending by `position` (column order).
    def self.for_board(access_token:, board_id:)
      opts = { filter: { boardId: board_id }.to_json, sort: "position", limit: LIST_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.lists_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.lists_collection_id,
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
        Mudbase::Config.lists_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.lists_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.delete!(access_token:, id:)
      Mudbase::ClientFactory.data_api(access_token: access_token).delete_data(
        Mudbase::Config.project_id,
        Mudbase::Config.lists_collection_id,
        id,
      )
    end
  end
end

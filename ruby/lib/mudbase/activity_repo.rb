# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `activity` - the board's reverse-chronological history log. Read
  # granted to all three roles; a row is only ever created as a side effect of a card/list
  # write, never edited or deleted, so this module exposes no `update!`/`delete!`.
  module ActivityRepo
    # Real platform ceiling on the generated SDK's `DataApi#list_data` (`limit <= 100`,
    # confirmed live by the sibling social port's own build) - the activity feed page shows the
    # most recent 100 entries, newest first.
    LIST_LIMIT = 100

    def self.for_board(access_token:, board_id:, limit: LIST_LIMIT)
      opts = { filter: { boardId: board_id }.to_json, sort: "-createdAt", limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.activity_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.activity_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end
  end
end

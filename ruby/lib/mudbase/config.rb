# frozen_string_literal: true

module Mudbase
  # Fails fast at boot with a clear message rather than surfacing a confusing
  # nil-related error deep inside a request handler later.
  class MissingEnvError < StandardError
    def initialize(name)
      super("Missing required environment variable: #{name}")
    end
  end

  module Config
    def self.require_env(name)
      value = ENV[name]
      raise MissingEnvError, name if value.nil? || value.empty?

      value
    end

    def self.base_url
      ENV.fetch("MUDBASE_URL", "https://cloud.mudbase.dev")
    end

    def self.project_id
      require_env("MUDBASE_PROJECT_ID")
    end

    # The single shared board this whole app operates on - not multi-tenant (see
    # plan/build-plan.md). A real 24-hex-char ObjectId (the id of the one document in a small
    # `boards` collection), not an arbitrary hand-picked hex string - Mudbase's query sanitizer
    # rejects any `...Id`-suffixed filter field that isn't genuinely ObjectId-shaped.
    def self.board_id
      require_env("BOARD_ID")
    end

    def self.lists_collection_id
      require_env("LISTS_COLLECTION_ID")
    end

    def self.cards_collection_id
      require_env("CARDS_COLLECTION_ID")
    end

    def self.activity_collection_id
      require_env("ACTIVITY_COLLECTION_ID")
    end

    def self.session_secret
      require_env("SESSION_SECRET")
    end
  end
end

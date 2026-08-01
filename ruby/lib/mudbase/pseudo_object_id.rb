# frozen_string_literal: true

module Mudbase
  # There is no `users` collection in this app's data model (see plan/build-plan.md), so a
  # card's assignee is captured as a free-typed display name rather than looked up from a
  # directory. Live testing against the real project proved `cards.assigneeId` is schema-typed
  # as an ObjectId reference, not a free-form string: a plain slug like `"mia-member"` is
  # rejected with `"Invalid ObjectId format for assigneeId"` by Mudbase's query/write
  # sanitizer - any field whose name ends in `Id` is validated as a real 24-hex-char ObjectId.
  # This derives a stable, valid-looking 24-hex-char id from the typed name (the same name
  # always maps to the same id) purely so `assigneeId` passes that format check and is never
  # left orphaned from `assigneeName` - it is not a real user lookup key. Mirrors
  # `pseudoObjectId()` in the reference web app's `src/lib/utils.ts`.
  module PseudoObjectId
    HEX_LENGTH = 24

    # djb2, a small deterministic string hash - used only to derive the pseudo id below.
    def self.djb2(str)
      hash = 5381
      str.each_byte { |byte| hash = ((hash * 33) ^ byte) & 0xFFFFFFFF }
      hash
    end

    # @param seed [String] the typed assignee display name.
    # @return [String] a stable, deterministic 24-hex-char string derived from `seed`.
    def self.generate(seed)
      trimmed = seed.to_s.strip.downcase
      hex = +""
      round = 0
      while hex.length < HEX_LENGTH
        hex << djb2("#{trimmed}:#{round}").to_s(16).rjust(8, "0")
        round += 1
      end
      hex[0, HEX_LENGTH]
    end
  end
end

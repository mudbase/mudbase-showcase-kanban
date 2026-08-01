# frozen_string_literal: true

require "time"

# ERB helpers shared by every view.
module ViewHelpers
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def format_datetime(iso_string)
    return "" if iso_string.nil? || iso_string.empty?

    Time.parse(iso_string).strftime("%b %-d, %Y %-I:%M %p")
  rescue ArgumentError
    iso_string.to_s
  end

  # Compact "3m", "2h", "5d" style relative time for the activity feed - falls back to an
  # absolute date once it's more than a week old, same threshold the reference web app's
  # `formatRelativeTime` uses.
  def format_relative(iso_string)
    return "" if iso_string.nil? || iso_string.empty?

    then_time = Time.parse(iso_string)
    seconds = (Time.now - then_time).to_i
    return "just now" if seconds < 60
    return "#{seconds / 60}m" if seconds < 3600
    return "#{seconds / 3600}h" if seconds < 86_400
    return "#{seconds / 86_400}d" if seconds < 604_800

    then_time.strftime("%b %-d, %Y")
  rescue ArgumentError
    iso_string.to_s
  end

  def initials(name)
    parts = name.to_s.strip.split(/\s+/)
    return "?" if parts.empty?
    return parts.first[0].upcase if parts.length == 1

    "#{parts.first[0]}#{parts.last[0]}".upcase
  end

  # Human-readable label for an `activity` row's `action` field, mirroring the reference web
  # app's `src/lib/activity-text.ts`.
  def activity_text(entry)
    actor = h(entry[:actorName])
    card = entry[:cardTitle] ? "“#{h(entry[:cardTitle])}”" : "a card"
    case entry[:action]
    when "created_card"
      "#{actor} created #{card} in #{h(entry[:toList])}"
    when "moved"
      if entry[:fromList] == entry[:toList]
        "#{actor} reordered #{card} in #{h(entry[:toList])}"
      else
        "#{actor} moved #{card} from #{h(entry[:fromList])} to #{h(entry[:toList])}"
      end
    when "deleted_card"
      "#{actor} deleted #{card} from #{h(entry[:fromList])}"
    when "created_list"
      "#{actor} added the list #{h(entry[:toList])}"
    when "renamed_list"
      "#{actor} renamed #{h(entry[:fromList])} to #{h(entry[:toList])}"
    when "deleted_list"
      "#{actor} deleted the list #{h(entry[:fromList])}"
    else
      "#{actor} updated the board"
    end
  end
end

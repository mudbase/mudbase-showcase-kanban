import type { ActivityEntry } from "@/types/activity"

/** Renders one activity row as a plain, readable sentence for the feed. */
export function describeActivity(entry: ActivityEntry): string {
  const who = entry.actorName || "Someone"
  switch (entry.action) {
    case "created_card":
      return `${who} created card "${entry.cardTitle ?? "Untitled"}" in ${entry.toList ?? "a list"}`
    case "moved":
      if (entry.fromList && entry.toList && entry.fromList === entry.toList) {
        return `${who} reordered "${entry.cardTitle ?? "a card"}" within ${entry.toList}`
      }
      return `${who} moved "${entry.cardTitle ?? "a card"}" from ${entry.fromList ?? "?"} to ${entry.toList ?? "?"}`
    case "deleted_card":
      return `${who} deleted card "${entry.cardTitle ?? "Untitled"}" from ${entry.fromList ?? "a list"}`
    case "created_list":
      return `${who} created list "${entry.toList ?? "Untitled"}"`
    case "renamed_list":
      return `${who} renamed list "${entry.fromList ?? "?"}" to "${entry.toList ?? "?"}"`
    case "deleted_list":
      return `${who} deleted list "${entry.fromList ?? "Untitled"}"`
    default:
      return `${who} did something on the board`
  }
}

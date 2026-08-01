package server

import (
	"fmt"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
)

// describeActivity renders one activity row as a plain, readable sentence for the feed. Ported
// from the reference web app's src/lib/activity-text.ts (describeActivity).
func describeActivity(entry models.Activity) string {
	who := entry.ActorName
	if who == "" {
		who = "Someone"
	}

	cardTitle := entry.CardTitle
	if cardTitle == "" {
		cardTitle = "a card"
	}

	switch entry.Action {
	case models.ActionCreatedCard:
		toList := entry.ToList
		if toList == "" {
			toList = "a list"
		}
		return fmt.Sprintf("%s created card %q in %s", who, orUntitled(entry.CardTitle), toList)
	case models.ActionMoved:
		if entry.FromList != "" && entry.FromList == entry.ToList {
			return fmt.Sprintf("%s reordered %q within %s", who, cardTitle, entry.ToList)
		}
		from := entry.FromList
		if from == "" {
			from = "?"
		}
		to := entry.ToList
		if to == "" {
			to = "?"
		}
		return fmt.Sprintf("%s moved %q from %s to %s", who, cardTitle, from, to)
	case models.ActionDeletedCard:
		fromList := entry.FromList
		if fromList == "" {
			fromList = "a list"
		}
		return fmt.Sprintf("%s deleted card %q from %s", who, orUntitled(entry.CardTitle), fromList)
	case models.ActionCreatedList:
		return fmt.Sprintf("%s created list %q", who, orUntitled(entry.ToList))
	case models.ActionRenamedList:
		from := entry.FromList
		if from == "" {
			from = "?"
		}
		to := entry.ToList
		if to == "" {
			to = "?"
		}
		return fmt.Sprintf("%s renamed list %q to %q", who, from, to)
	case models.ActionDeletedList:
		return fmt.Sprintf("%s deleted list %q", who, orUntitled(entry.FromList))
	default:
		return fmt.Sprintf("%s did something on the board", who)
	}
}

func orUntitled(s string) string {
	if s == "" {
		return "Untitled"
	}
	return s
}

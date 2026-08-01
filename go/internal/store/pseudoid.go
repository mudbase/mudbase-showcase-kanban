package store

import (
	"fmt"
	"strings"
)

// djb2 is a small deterministic string hash - used below to derive a stable pseudo-ObjectId,
// nothing more. Ported bit-for-bit from the reference web app's src/lib/utils.ts.
func djb2(str string) uint32 {
	var hash uint32 = 5381
	for _, r := range str {
		hash = (hash * 33) ^ uint32(r)
	}
	return hash
}

// pseudoObjectID derives a stable, valid-looking 24-hex-char id from a typed assignee name, purely
// so `cards.assigneeId` passes Mudbase's ObjectId format check and is never left orphaned from
// `assigneeName`. There is no `users` collection in this app's data model (see
// plan/build-plan.md), so an assignee is captured as a free-typed name rather than looked up from
// a directory - but the platform's query sanitizer validates any field named `...Id` as an
// ObjectId reference (confirmed live: a plain slug like "mia-member" is rejected with "Invalid
// ObjectId format for assigneeId"). The same name always maps to the same id; this is not a real
// user lookup key. Ported bit-for-bit from the reference web app's src/lib/utils.ts
// (pseudoObjectId).
func pseudoObjectID(seed string) string {
	trimmed := strings.ToLower(strings.TrimSpace(seed))
	var hex strings.Builder
	for round := 0; hex.Len() < 24; round++ {
		hex.WriteString(fmt.Sprintf("%08x", djb2(fmt.Sprintf("%s:%d", trimmed, round))))
	}
	return hex.String()[:24]
}

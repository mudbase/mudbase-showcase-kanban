package dev.mudbase.showcase.kanban.support;

import java.util.Locale;

/**
 * There is no `users` collection in this app's data model (see plan/build-plan.md), so a card's
 * assignee is captured as a free-typed name rather than looked up from a directory. Verified live
 * against the real project: {@code cards.assigneeId} is schema-typed as an ObjectId reference,
 * not a free-form string as originally assumed - a plain slug like "mia-member" is rejected with
 * "Invalid ObjectId format for assigneeId". This derives a stable, valid-looking 24-hex-char id
 * from the typed name (the same name always maps to the same id) purely so `assigneeId` passes
 * that format check and is never left orphaned from `assigneeName` - it is not a real user lookup
 * key. Ported from the reference web app's `pseudoObjectId()` (../web/src/lib/utils.ts) - same
 * djb2-based algorithm, so the same assignee name produces the identical id in both apps.
 */
public final class PseudoObjectId {

  private PseudoObjectId() {}

  /**
   * djb2, a small deterministic string hash. Java's {@code int} is 32-bit two's-complement with
   * wraparound-on-overflow multiplication/XOR, which is bit-for-bit equivalent to the TypeScript
   * version's {@code (hash * 33) ^ charCode} followed by an implicit ToInt32 - so this produces
   * the same hash for the same input in both languages.
   */
  private static long djb2(String str) {
    int hash = 5381;
    for (int i = 0; i < str.length(); i++) {
      hash = (hash * 33) ^ str.charAt(i);
    }
    // Reinterpret as unsigned 32-bit, matching the TypeScript version's `>>> 0`.
    return hash & 0xFFFFFFFFL;
  }

  public static String generate(String seed) {
    String trimmed = seed.trim().toLowerCase(Locale.ROOT);
    StringBuilder hex = new StringBuilder();
    for (int round = 0; hex.length() < 24; round++) {
      String part = Long.toHexString(djb2(trimmed + ":" + round));
      while (part.length() < 8) {
        part = "0" + part;
      }
      hex.append(part);
    }
    return hex.substring(0, 24);
  }
}

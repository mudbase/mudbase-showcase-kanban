using System.Text;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>
/// There is no users collection in this app's data model (see plan/build-plan.md), so an assignee
/// is captured as a free-typed name rather than looked up from a directory. Verified live against
/// the real project: `cards.assigneeId` is schema-typed as an ObjectId reference, not a free-form
/// string as originally assumed - a plain slug like "mia-member" is rejected with "Invalid
/// ObjectId format for assigneeId". This derives a stable, valid-looking 24-hex-char id from the
/// typed name (same name always maps to the same id) purely so `assigneeId` passes that format
/// check and is never left orphaned from `assigneeName` - it is not a real user lookup key. Direct
/// port of web/src/lib/utils.ts's pseudoObjectId (djb2 hash, same algorithm, same output).
/// </summary>
public static class PseudoObjectId
{
    public static string From(string seed)
    {
        string trimmed = seed.Trim().ToLowerInvariant();
        StringBuilder hex = new();
        int round = 0;
        while (hex.Length < 24)
        {
            uint hash = Djb2($"{trimmed}:{round}");
            hex.Append(hash.ToString("x8"));
            round++;
        }

        return hex.ToString(0, 24);
    }

    /// <summary>djb2, a small deterministic string hash - used only to derive a stable pseudo-ObjectId, nothing more.</summary>
    private static uint Djb2(string str)
    {
        unchecked
        {
            uint hash = 5381;
            foreach (char c in str)
            {
                hash = (hash * 33) ^ c;
            }

            return hash;
        }
    }
}

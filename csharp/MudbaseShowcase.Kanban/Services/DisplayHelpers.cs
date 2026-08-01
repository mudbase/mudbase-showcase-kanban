using System.Globalization;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>Small display-formatting helpers shared by Razor views. Mirrors web/src/lib/utils.ts's formatRelativeTime/initials.</summary>
public static class DisplayHelpers
{
    public static string FormatRelativeTime(DateTimeOffset value)
    {
        double seconds = (DateTimeOffset.UtcNow - value).TotalSeconds;

        if (seconds < 5) return "just now";
        if (seconds < 60) return $"{(int)seconds}s";

        double minutes = Math.Round(seconds / 60);
        if (minutes < 60) return $"{(int)minutes}m";

        double hours = Math.Round(minutes / 60);
        if (hours < 24) return $"{(int)hours}h";

        double days = Math.Round(hours / 24);
        if (days < 7) return $"{(int)days}d";

        return value.ToLocalTime().ToString("MMM d, yyyy", CultureInfo.InvariantCulture);
    }

    public static string Initials(string name)
    {
        string[] parts = name.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return "?";

        string first = parts[0][..1];
        string last = parts.Length > 1 ? parts[^1][..1] : string.Empty;
        return (first + last).ToUpperInvariant();
    }
}

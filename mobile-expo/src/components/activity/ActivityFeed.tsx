import { useCallback } from "react";
import { ActivityIndicator, FlatList, RefreshControl, Text, View } from "react-native";
import { Separator } from "@/components/ui/Separator";
import { useActivityFeed } from "@/hooks/useActivity";
import { useBoardLive } from "@/hooks/useBoardLive";
import { ActivityItem } from "@/components/activity/ActivityItem";
import type { ActivityEntry } from "@/api/schemas";

/**
 * Reverse-chronological activity feed. Unlike the board's columns/cards (demo-scale, rendered
 * with a plain `.map()` — see BoardScreenContent), this feed can grow past demo scale (server
 * caps it at 200 rows) so it uses a real `FlatList`, per the react-native-perf skill's guidance
 * for anything list-shaped and potentially long. Mirrors web/src/components/activity/ActivityFeed.tsx.
 */
export function ActivityFeed(): React.JSX.Element {
  const { data, isLoading, isError, isRefetching, refetch } = useActivityFeed();
  useBoardLive(!isLoading);

  const entries = data?.data ?? [];

  const renderItem = useCallback(({ item }: { item: ActivityEntry }) => <ActivityItem entry={item} />, []);
  const keyExtractor = useCallback((item: ActivityEntry) => item._id, []);

  if (isLoading) {
    return (
      <View className="flex-1 items-center justify-center py-16">
        <ActivityIndicator size="large" color="#4a43db" />
      </View>
    );
  }

  if (isError) {
    return (
      <View className="flex-1 items-center justify-center px-6 py-16">
        <Text className="text-center text-sm text-destructive">
          Failed to load activity. Pull to refresh or restart the app.
        </Text>
      </View>
    );
  }

  return (
    <FlatList
      data={entries}
      keyExtractor={keyExtractor}
      renderItem={renderItem}
      contentContainerClassName="px-4 pb-8"
      ItemSeparatorComponent={() => <Separator />}
      refreshControl={<RefreshControl refreshing={isRefetching} onRefresh={() => void refetch()} tintColor="#4a43db" />}
      ListEmptyComponent={
        <View className="items-center py-16">
          <Text className="text-sm text-muted-foreground">No activity yet — actions on the board will show up here.</Text>
        </View>
      }
    />
  );
}

import { useMemo } from "react";
import { ActivityIndicator, ScrollView, Text, View } from "react-native";
import { useAuth } from "@/hooks/useAuth";
import { useBoardLists } from "@/hooks/useLists";
import { useBoardCards } from "@/hooks/useCards";
import { useBoardLive } from "@/hooks/useBoardLive";
import { canManageLists, canManageCards, isReadOnly, roleLabel } from "@/lib/rbac";
import { ListColumn } from "@/components/board/ListColumn";
import { AddListForm } from "@/components/board/AddListForm";
import type { BoardCard } from "@/api/schemas";

/** The board screen's content — everything below AppHeader. Mirrors
 * web/src/components/board/BoardView.tsx. */
export function BoardScreenContent(): React.JSX.Element {
  const { role } = useAuth();
  const listsQuery = useBoardLists();
  const cardsQuery = useBoardCards();

  const isLoading = listsQuery.isLoading || cardsQuery.isLoading;
  useBoardLive(!isLoading);

  const lists = useMemo(
    () => [...(listsQuery.data?.data ?? [])].sort((a, b) => a.position - b.position),
    [listsQuery.data],
  );

  const cardsByListId = useMemo(() => {
    const cards = cardsQuery.data?.data ?? [];
    const map = new Map<string, BoardCard[]>();
    for (const card of cards) {
      const bucket = map.get(card.listId) ?? [];
      bucket.push(card);
      map.set(card.listId, bucket);
    }
    for (const bucket of map.values()) bucket.sort((a, b) => a.position - b.position);
    return map;
  }, [cardsQuery.data]);

  const nextListPosition = useMemo(
    () => (lists.length === 0 ? 0 : Math.max(...lists.map((l) => l.position)) + 1),
    [lists],
  );

  const nextPositionByListId = useMemo(() => {
    const map: Record<string, number> = {};
    for (const list of lists) {
      const inList = cardsByListId.get(list._id) ?? [];
      map[list._id] = inList.length === 0 ? 0 : Math.max(...inList.map((c) => c.position)) + 1;
    }
    return map;
  }, [lists, cardsByListId]);

  const manageLists = canManageLists(role);
  const manageCards = canManageCards(role);
  const readOnly = isReadOnly(role);

  if (isLoading) {
    return (
      <View className="flex-1 items-center justify-center py-16">
        <ActivityIndicator size="large" color="#4a43db" />
      </View>
    );
  }

  if (listsQuery.isError || cardsQuery.isError) {
    return (
      <View className="flex-1 items-center justify-center px-6 py-16">
        <Text className="text-center text-sm text-destructive">
          Failed to load the board. Pull to refresh or restart the app.
        </Text>
      </View>
    );
  }

  return (
    <View className="flex-1">
      {readOnly && (
        <View className="mx-4 mb-2 rounded-md border border-border bg-muted px-3 py-2">
          <Text className="text-xs text-muted-foreground">
            Read-only — you&apos;re signed in as {roleLabel(role)}
          </Text>
        </View>
      )}

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerClassName="gap-3 px-4 pb-8"
      >
        {lists.map((list, index) => {
          const cardsInList = cardsByListId.get(list._id) ?? [];
          return (
            <ListColumn
              key={list._id}
              list={list}
              cards={cardsInList}
              allCardsInList={cardsInList}
              otherLists={lists.filter((l) => l._id !== list._id)}
              nextPositionByListId={nextPositionByListId}
              prevList={lists[index - 1]}
              nextList={lists[index + 1]}
              canManageLists={manageLists}
              canManageCards={manageCards}
            />
          );
        })}

        {manageLists && <AddListForm nextPosition={nextListPosition} />}

        {lists.length === 0 && !manageLists && (
          <Text className="text-sm text-muted-foreground">The board has no lists yet.</Text>
        )}
      </ScrollView>
    </View>
  );
}

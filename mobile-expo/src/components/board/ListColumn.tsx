import { useState } from "react";
import { Text, View } from "react-native";
import { ChevronLeft, ChevronRight, Pencil, Plus, Trash2 } from "lucide-react-native";
import { z } from "zod";
import { useDeleteList, useRenameList, useReorderList } from "@/hooks/useLists";
import { Button } from "@/components/ui/Button";
import { IconButton } from "@/components/ui/IconButton";
import { TextField } from "@/components/ui/TextField";
import { CardItem } from "@/components/board/CardItem";
import { CardFormModal } from "@/components/board/CardFormModal";
import type { BoardCard, BoardList } from "@/api/schemas";

const listNameSchema = z.string().min(1, "Name is required").max(60, "Keep the name under 60 characters");

interface ListColumnProps {
  list: BoardList;
  cards: BoardCard[];
  otherLists: BoardList[];
  nextPositionByListId: Record<string, number>;
  prevList?: BoardList;
  nextList?: BoardList;
  allCardsInList: BoardCard[];
  canManageLists: boolean;
  canManageCards: boolean;
}

/** One board column. Mirrors web/src/components/board/ListColumn.tsx. Not virtualized — this
 * board operates at demo scale (a handful of lists/cards, see plan/build-plan.md), matching the
 * web reference's own choice not to virtualize at this size. */
export function ListColumn({
  list,
  cards,
  otherLists,
  nextPositionByListId,
  prevList,
  nextList,
  allCardsInList,
  canManageLists,
  canManageCards,
}: ListColumnProps): React.JSX.Element {
  const [renaming, setRenaming] = useState(false);
  const [draftName, setDraftName] = useState(list.name);
  const [nameError, setNameError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [creatingCard, setCreatingCard] = useState(false);

  const renameList = useRenameList();
  const deleteList = useDeleteList();
  const reorderList = useReorderList();

  const startRename = (): void => {
    setDraftName(list.name);
    setNameError(null);
    setRenaming(true);
  };

  const saveRename = (): void => {
    const parsed = listNameSchema.safeParse(draftName.trim());
    if (!parsed.success) {
      setNameError(parsed.error.issues[0]?.message ?? "Invalid name");
      return;
    }
    if (parsed.data === list.name) {
      setRenaming(false);
      return;
    }
    renameList.mutate({ list, newName: parsed.data }, { onSuccess: () => setRenaming(false) });
  };

  const handleDelete = (): void => {
    deleteList.mutate({ list, cardsInList: allCardsInList });
    setConfirmDelete(false);
  };

  return (
    <View className="w-64 shrink-0 gap-2 rounded-lg border border-border bg-secondary/40 p-3">
      {renaming ? (
        <View className="gap-1.5">
          <TextField autoFocus value={draftName} onChangeText={setDraftName} error={nameError ?? undefined} />
          <View className="flex-row gap-2">
            <Button size="sm" className="flex-1" isLoading={renameList.isPending} onPress={saveRename}>
              Save
            </Button>
            <Button size="sm" variant="outline" className="flex-1" onPress={() => setRenaming(false)}>
              Cancel
            </Button>
          </View>
        </View>
      ) : (
        <View className="flex-row items-center justify-between gap-2">
          <Text className="flex-1 text-sm font-semibold text-foreground" numberOfLines={1}>
            {list.name} <Text className="font-normal text-muted-foreground">({cards.length})</Text>
          </Text>
          {canManageLists && (
            <View className="flex-row gap-0.5">
              <IconButton accessibilityLabel="Move list left" disabled={!prevList || reorderList.isPending} onPress={() => prevList && reorderList.mutate({ list, neighbor: prevList })}>
                <ChevronLeft size={14} color="#181c25" />
              </IconButton>
              <IconButton accessibilityLabel="Move list right" disabled={!nextList || reorderList.isPending} onPress={() => nextList && reorderList.mutate({ list, neighbor: nextList })}>
                <ChevronRight size={14} color="#181c25" />
              </IconButton>
              <IconButton accessibilityLabel="Rename list" onPress={startRename}>
                <Pencil size={14} color="#181c25" />
              </IconButton>
              <IconButton accessibilityLabel="Delete list" onPress={() => setConfirmDelete(true)}>
                <Trash2 size={14} color="#e42545" />
              </IconButton>
            </View>
          )}
        </View>
      )}

      {confirmDelete && (
        <View className="gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-2">
          <Text className="text-xs text-foreground">
            Delete &quot;{list.name}&quot;
            {allCardsInList.length > 0 ? ` and its ${allCardsInList.length} card(s)` : ""}?
          </Text>
          <View className="flex-row gap-2">
            <Button variant="destructive" size="sm" className="flex-1" isLoading={deleteList.isPending} onPress={handleDelete}>
              {deleteList.isPending ? "Deleting…" : "Delete"}
            </Button>
            <Button variant="outline" size="sm" className="flex-1" onPress={() => setConfirmDelete(false)}>
              Cancel
            </Button>
          </View>
        </View>
      )}

      <View className="gap-2">
        {cards.map((card, index) => (
          <CardItem
            key={card._id}
            card={card}
            list={list}
            otherLists={otherLists}
            nextPositionByListId={nextPositionByListId}
            prevCard={cards[index - 1]}
            nextCard={cards[index + 1]}
            canManage={canManageCards}
          />
        ))}
        {cards.length === 0 && (
          <Text className="py-4 text-center text-xs text-muted-foreground">No cards yet</Text>
        )}
      </View>

      {canManageCards && (
        <>
          <Button
            variant="ghost"
            size="sm"
            icon={<Plus size={16} color="#181c25" />}
            onPress={() => setCreatingCard(true)}
          >
            Add card
          </Button>
          <CardFormModal
            open={creatingCard}
            onClose={() => setCreatingCard(false)}
            listId={list._id}
            listName={list.name}
            nextPosition={nextPositionByListId[list._id] ?? 0}
          />
        </>
      )}
    </View>
  );
}

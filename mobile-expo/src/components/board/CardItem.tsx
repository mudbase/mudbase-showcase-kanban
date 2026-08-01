import { useState } from "react";
import { Text, View } from "react-native";
import { ChevronDown, ChevronUp, Pencil, Trash2 } from "lucide-react-native";
import { useDeleteCard, useReorderCardInList } from "@/hooks/useCards";
import { Card } from "@/components/ui/Card";
import { IconButton } from "@/components/ui/IconButton";
import { Button } from "@/components/ui/Button";
import { Avatar } from "@/components/ui/Avatar";
import { CardFormModal } from "@/components/board/CardFormModal";
import { MoveCardPicker } from "@/components/board/MoveCardPicker";
import type { BoardCard, BoardList } from "@/api/schemas";

interface CardItemProps {
  card: BoardCard;
  list: BoardList;
  otherLists: BoardList[];
  nextPositionByListId: Record<string, number>;
  prevCard?: BoardCard;
  nextCard?: BoardCard;
  canManage: boolean;
}

/** One card within a column. Mirrors web/src/components/board/CardItem.tsx. */
export function CardItem({
  card,
  list,
  otherLists,
  nextPositionByListId,
  prevCard,
  nextCard,
  canManage,
}: CardItemProps): React.JSX.Element {
  const [editOpen, setEditOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const deleteCard = useDeleteCard();
  const reorderCard = useReorderCardInList();

  const handleDelete = (): void => {
    deleteCard.mutate({ card, listName: list.name });
    setConfirmDelete(false);
  };

  return (
    <Card className="gap-2">
      <View className="flex-row items-start justify-between gap-2">
        <Text className="flex-1 text-sm font-medium leading-snug text-foreground">{card.title}</Text>
        {canManage && (
          <View className="flex-row gap-0.5">
            <IconButton accessibilityLabel="Edit card" onPress={() => setEditOpen(true)}>
              <Pencil size={14} color="#181c25" />
            </IconButton>
            <IconButton accessibilityLabel="Delete card" onPress={() => setConfirmDelete(true)}>
              <Trash2 size={14} color="#e42545" />
            </IconButton>
          </View>
        )}
      </View>

      {card.description && (
        <Text numberOfLines={3} className="text-xs text-muted-foreground">
          {card.description}
        </Text>
      )}

      {card.assigneeName && (
        <View className="flex-row items-center gap-1.5 pt-1">
          <Avatar name={card.assigneeName} size="sm" />
          <Text className="text-xs text-muted-foreground">{card.assigneeName}</Text>
        </View>
      )}

      {confirmDelete && (
        <View className="gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-2">
          <Text className="text-xs text-foreground">Delete this card?</Text>
          <View className="flex-row gap-2">
            <Button
              variant="destructive"
              size="sm"
              className="flex-1"
              isLoading={deleteCard.isPending}
              onPress={handleDelete}
            >
              {deleteCard.isPending ? "Deleting…" : "Delete"}
            </Button>
            <Button variant="outline" size="sm" className="flex-1" onPress={() => setConfirmDelete(false)}>
              Cancel
            </Button>
          </View>
        </View>
      )}

      {canManage && (
        <View className="flex-row items-center gap-1.5 pt-1">
          <IconButton
            accessibilityLabel="Move up"
            disabled={!prevCard || reorderCard.isPending}
            onPress={() => prevCard && reorderCard.mutate({ card, neighbor: prevCard, listName: list.name })}
          >
            <ChevronUp size={16} color="#181c25" />
          </IconButton>
          <IconButton
            accessibilityLabel="Move down"
            disabled={!nextCard || reorderCard.isPending}
            onPress={() => nextCard && reorderCard.mutate({ card, neighbor: nextCard, listName: list.name })}
          >
            <ChevronDown size={16} color="#181c25" />
          </IconButton>
          <MoveCardPicker
            card={card}
            currentList={list}
            otherLists={otherLists}
            nextPositionByListId={nextPositionByListId}
          />
        </View>
      )}

      {canManage && (
        <CardFormModal
          open={editOpen}
          onClose={() => setEditOpen(false)}
          listId={list._id}
          listName={list.name}
          nextPosition={card.position}
          editingCard={card}
        />
      )}
    </Card>
  );
}

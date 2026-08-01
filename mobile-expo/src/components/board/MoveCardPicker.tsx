import { useState } from "react";
import { Modal, Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { ArrowRightLeft, X } from "lucide-react-native";
import { useMoveCardToList } from "@/hooks/useCards";
import { Button } from "@/components/ui/Button";
import type { BoardCard, BoardList } from "@/api/schemas";

interface MoveCardPickerProps {
  card: BoardCard;
  currentList: BoardList;
  otherLists: BoardList[];
  nextPositionByListId: Record<string, number>;
}

/**
 * "Move to…" picker: a small centered Modal listing the other columns as tappable rows — the RN
 * equivalent of the web reference's `<Select>` dropdown (see web/src/components/board/MoveCardControl.tsx).
 * Moving a card to a different column always appends it to the end of that column; reordering
 * within the same column is handled separately by the up/down buttons in CardItem.
 */
export function MoveCardPicker({
  card,
  currentList,
  otherLists,
  nextPositionByListId,
}: MoveCardPickerProps): React.JSX.Element | null {
  const [open, setOpen] = useState(false);
  const moveCard = useMoveCardToList();

  if (otherLists.length === 0) return null;

  const handleMove = (target: BoardList): void => {
    moveCard.mutate(
      {
        card,
        fromListName: currentList.name,
        toListId: target._id,
        toListName: target.name,
        newPosition: nextPositionByListId[target._id] ?? 0,
      },
      { onSettled: () => setOpen(false) },
    );
  };

  return (
    <>
      <Button
        variant="outline"
        size="sm"
        className="flex-1"
        icon={<ArrowRightLeft size={14} color="#181c25" />}
        onPress={() => setOpen(true)}
      >
        Move to…
      </Button>

      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <View className="flex-1 justify-end bg-black/40">
          <Pressable className="absolute inset-0" onPress={() => setOpen(false)} accessibilityLabel="Close" />
          <SafeAreaView edges={["bottom"]} className="rounded-t-2xl bg-card">
            <View className="flex-row items-center justify-between border-b border-border p-4">
              <Text className="text-base font-semibold text-foreground">Move &quot;{card.title}&quot; to…</Text>
              <Pressable accessibilityRole="button" accessibilityLabel="Close" onPress={() => setOpen(false)}>
                <X size={20} color="#606876" />
              </Pressable>
            </View>
            <View className="gap-1 p-2">
              {otherLists.map((list) => (
                <Pressable
                  key={list._id}
                  accessibilityRole="button"
                  disabled={moveCard.isPending}
                  onPress={() => handleMove(list)}
                  className="rounded-md px-4 py-3 active:bg-secondary"
                >
                  <Text className="text-base text-foreground">{list.name}</Text>
                </Pressable>
              ))}
            </View>
          </SafeAreaView>
        </View>
      </Modal>
    </>
  );
}

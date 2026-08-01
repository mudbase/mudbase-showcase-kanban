import { useState } from "react";
import { View } from "react-native";
import { Plus } from "lucide-react-native";
import { z } from "zod";
import { useCreateList } from "@/hooks/useLists";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";

const listNameSchema = z.string().min(1, "Name is required").max(60, "Keep the name under 60 characters");

interface AddListFormProps {
  nextPosition: number;
}

/** Owner-only column at the end of the board row for adding a new list. Mirrors
 * web/src/components/board/AddListForm.tsx. */
export function AddListForm({ nextPosition }: AddListFormProps): React.JSX.Element {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const createList = useCreateList();

  const handleSubmit = (): void => {
    const parsed = listNameSchema.safeParse(name.trim());
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "Invalid name");
      return;
    }
    createList.mutate(
      { name: parsed.data, position: nextPosition },
      {
        onSuccess: () => {
          setName("");
          setError(null);
          setOpen(false);
        },
      },
    );
  };

  if (!open) {
    return (
      <View className="w-64 shrink-0">
        <Button variant="outline" icon={<Plus size={16} color="#181c25" />} onPress={() => setOpen(true)}>
          Add list
        </Button>
      </View>
    );
  }

  return (
    <View className="w-64 shrink-0 gap-2 rounded-lg border border-border bg-card p-3">
      <TextField
        autoFocus
        placeholder="List name"
        value={name}
        onChangeText={setName}
        error={error ?? undefined}
      />
      <View className="flex-row gap-2">
        <Button size="sm" className="flex-1" isLoading={createList.isPending} onPress={handleSubmit}>
          {createList.isPending ? "Adding…" : "Add list"}
        </Button>
        <Button size="sm" variant="outline" className="flex-1" onPress={() => setOpen(false)}>
          Cancel
        </Button>
      </View>
    </View>
  );
}

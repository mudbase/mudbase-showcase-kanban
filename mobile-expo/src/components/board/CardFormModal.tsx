import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { X } from "lucide-react-native";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { useCreateCard, useUpdateCard } from "@/hooks/useCards";
import { pseudoObjectId } from "@/lib/format";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";
import { ErrorNotice } from "@/components/ui/ErrorNotice";
import type { BoardCard } from "@/api/schemas";

const cardSchema = z.object({
  title: z.string().min(1, "Title is required").max(120, "Keep the title under 120 characters"),
  description: z.string().max(2000, "Keep the description under 2000 characters").optional(),
  assigneeName: z.string().max(80, "Keep the assignee name under 80 characters").optional(),
});

type CardFormValues = z.infer<typeof cardSchema>;

interface CardFormModalProps {
  open: boolean;
  onClose: () => void;
  listId: string;
  listName: string;
  nextPosition: number;
  editingCard?: BoardCard;
}

/** Create-or-edit modal for a card. Which mode it's in is determined by whether `editingCard`
 * is present — both modes share the same form and validation. Mirrors
 * web/src/components/board/CardDialog.tsx. */
export function CardFormModal({
  open,
  onClose,
  listId,
  listName,
  nextPosition,
  editingCard,
}: CardFormModalProps): React.JSX.Element {
  const { user } = useAuth();
  const createCard = useCreateCard();
  const updateCard = useUpdateCard();
  const isEditing = !!editingCard;
  const [submitError, setSubmitError] = useState<string | null>(null);

  const {
    control,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CardFormValues>({
    resolver: zodResolver(cardSchema),
    defaultValues: { title: "", description: "", assigneeName: "" },
  });

  useEffect(() => {
    if (open) {
      reset({
        title: editingCard?.title ?? "",
        description: editingCard?.description ?? "",
        assigneeName: editingCard?.assigneeName ?? "",
      });
      setSubmitError(null);
    }
  }, [open, editingCard, reset]);

  const onSubmit = async (values: CardFormValues): Promise<void> => {
    setSubmitError(null);
    const assigneeName = values.assigneeName?.trim() || undefined;
    try {
      if (isEditing && editingCard) {
        await updateCard.mutateAsync({
          card: editingCard,
          title: values.title.trim(),
          description: values.description?.trim(),
          assigneeId: assigneeName ? pseudoObjectId(assigneeName) : undefined,
          assigneeName,
        });
      } else {
        if (!user) throw new Error("Must be signed in");
        await createCard.mutateAsync({
          listId,
          listName,
          position: nextPosition,
          title: values.title.trim(),
          description: values.description?.trim(),
          assigneeId: assigneeName ? pseudoObjectId(assigneeName) : undefined,
          assigneeName,
        });
      }
      onClose();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Something went wrong");
    }
  };

  const pending = createCard.isPending || updateCard.isPending;

  return (
    <Modal visible={open} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : "height"}
        className="flex-1 justify-end bg-black/40"
      >
        <Pressable className="absolute inset-0" onPress={onClose} accessibilityLabel="Close" />
        <SafeAreaView edges={["bottom"]} className="max-h-[85%] rounded-t-2xl bg-card">
          <View className="flex-row items-center justify-between border-b border-border p-4">
            <View className="flex-1 gap-0.5">
              <Text className="text-base font-semibold text-foreground">
                {isEditing ? "Edit card" : `New card in ${listName}`}
              </Text>
              <Text className="text-xs text-muted-foreground">
                {isEditing ? "Update the card's details." : "Add a task to this column."}
              </Text>
            </View>
            <Pressable accessibilityRole="button" accessibilityLabel="Close" onPress={onClose}>
              <X size={20} color="#606876" />
            </Pressable>
          </View>

          <ScrollView contentContainerClassName="gap-4 p-4" keyboardShouldPersistTaps="handled">
            <Controller
              control={control}
              name="title"
              render={({ field: { onChange, onBlur, value } }) => (
                <TextField
                  label="Title"
                  value={value}
                  onChangeText={onChange}
                  onBlur={onBlur}
                  placeholder="e.g. Write onboarding docs"
                  error={errors.title?.message}
                />
              )}
            />
            <Controller
              control={control}
              name="description"
              render={({ field: { onChange, onBlur, value } }) => (
                <TextField
                  label="Description (optional)"
                  value={value}
                  onChangeText={onChange}
                  onBlur={onBlur}
                  multiline
                  numberOfLines={4}
                  className="min-h-24"
                  textAlignVertical="top"
                  error={errors.description?.message}
                />
              )}
            />
            <Controller
              control={control}
              name="assigneeName"
              render={({ field: { onChange, onBlur, value } }) => (
                <TextField
                  label="Assignee (optional)"
                  value={value}
                  onChangeText={onChange}
                  onBlur={onBlur}
                  placeholder="e.g. Ben Chen"
                  error={errors.assigneeName?.message}
                />
              )}
            />

            {submitError && <ErrorNotice message={submitError} />}

            <View className="flex-row gap-2 pt-2">
              <Button variant="outline" className="flex-1" onPress={onClose}>
                Cancel
              </Button>
              <Button className="flex-1" isLoading={pending} onPress={handleSubmit(onSubmit)}>
                {pending ? "Saving…" : isEditing ? "Save changes" : "Create card"}
              </Button>
            </View>
          </ScrollView>
        </SafeAreaView>
      </KeyboardAvoidingView>
    </Modal>
  );
}

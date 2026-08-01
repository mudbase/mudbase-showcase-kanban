import { useCallback } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient } from "@/api/client";
import { boardCardSchema, activityEntrySchema, type BoardCard } from "@/api/schemas";
import { CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/config/env";
import { useAuth } from "@/hooks/useAuth";

/** All cards for the single shared board, ascending by in-column order — fetched once and
 * grouped client-side by listId (see BoardScreenContent), rather than one query per column.
 * Mirrors web/src/hooks/useCards.ts's useBoardCards. */
export function useBoardCards() {
  return useQuery({
    queryKey: ["collection", CARDS_COLLECTION_ID, { boardId: BOARD_ID }],
    queryFn: () =>
      mudbaseClient.listDocuments(boardCardSchema, CARDS_COLLECTION_ID, {
        filter: { boardId: BOARD_ID },
        sort: "position",
      }),
  });
}

interface ActorFields {
  actorId: string;
  actorName: string;
}

function actorFields(user: { id: string; firstName: string; lastName: string } | null | undefined): ActorFields {
  if (!user) throw new Error("Must be signed in");
  return { actorId: user.id, actorName: `${user.firstName} ${user.lastName}`.trim() };
}

function invalidateBoard(queryClient: ReturnType<typeof useQueryClient>): void {
  void queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] });
  void queryClient.invalidateQueries({ queryKey: ["collection", ACTIVITY_COLLECTION_ID] });
}

export interface CreateCardInput {
  listId: string;
  listName: string;
  position: number;
  title: string;
  description?: string;
  assigneeId?: string;
  assigneeName?: string;
}

/** Owner/member: creates a new card at the end of a column. */
export function useCreateCard() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async (input: CreateCardInput): Promise<BoardCard> => {
      const { actorId, actorName } = actorFields(user);
      const created = await mudbaseClient.createDocument(boardCardSchema, CARDS_COLLECTION_ID, {
        boardId: BOARD_ID,
        listId: input.listId,
        title: input.title,
        position: input.position,
        ...(input.description ? { description: input.description } : {}),
        ...(input.assigneeId ? { assigneeId: input.assigneeId, assigneeName: input.assigneeName } : {}),
        createdById: actorId,
        createdByName: actorName,
      });
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "created_card",
        cardTitle: input.title,
        toList: input.listName,
      });
      return created;
    },
    [user],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  });
}

export interface EditCardInput {
  card: BoardCard;
  title: string;
  description?: string;
  assigneeId?: string;
  assigneeName?: string;
}

/** Owner/member: edits a card's title/description/assignee in place. Not itself logged to the
 * activity feed — only creation, movement, and deletion are. */
export function useUpdateCard() {
  const queryClient = useQueryClient();

  const mutate = useCallback(async (input: EditCardInput): Promise<BoardCard> => {
    // `assigneeId` is validated server-side as an ObjectId reference (verified live in the web
    // reference build) — an empty string fails that check the same way an invalid slug would
    // ("Invalid ObjectId format for assigneeId"). `null` is the value that actually clears it;
    // never send "" here.
    return mudbaseClient.updateDocument(boardCardSchema, CARDS_COLLECTION_ID, input.card._id, {
      title: input.title,
      description: input.description ?? "",
      assigneeId: input.assigneeId ?? null,
      assigneeName: input.assigneeName ?? null,
    });
  }, []);

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] }),
  });
}

/** Owner/member: deletes a card. */
export function useDeleteCard() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async ({ card, listName }: { card: BoardCard; listName: string }): Promise<void> => {
      const { actorId, actorName } = actorFields(user);
      await mudbaseClient.deleteDocument(CARDS_COLLECTION_ID, card._id);
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "deleted_card",
        cardTitle: card.title,
        fromList: listName,
      });
    },
    [user],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  });
}

/** Owner/member: moves a card to a different column, appended to the end of it. Every move
 * writes both `listId` and `position` and appends a `moved` activity entry, per the task spec. */
export function useMoveCardToList() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async (params: {
      card: BoardCard;
      fromListName: string;
      toListId: string;
      toListName: string;
      newPosition: number;
    }): Promise<BoardCard> => {
      const { actorId, actorName } = actorFields(user);
      const updated = await mudbaseClient.updateDocument(boardCardSchema, CARDS_COLLECTION_ID, params.card._id, {
        listId: params.toListId,
        position: params.newPosition,
      });
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "moved",
        cardTitle: params.card.title,
        fromList: params.fromListName,
        toList: params.toListName,
      });
      return updated;
    },
    [user],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  });
}

/** Owner/member: reorders a card up/down within its own column by swapping `position` with the
 * adjacent card. Still logs a `moved` activity entry (fromList === toList) per the task's
 * "every move...appends an activity entry" requirement. */
export function useReorderCardInList() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async (params: { card: BoardCard; neighbor: BoardCard; listName: string }): Promise<void> => {
      const { actorId, actorName } = actorFields(user);
      await Promise.all([
        mudbaseClient.updateDocument(boardCardSchema, CARDS_COLLECTION_ID, params.card._id, {
          position: params.neighbor.position,
        }),
        mudbaseClient.updateDocument(boardCardSchema, CARDS_COLLECTION_ID, params.neighbor._id, {
          position: params.card.position,
        }),
      ]);
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "moved",
        cardTitle: params.card.title,
        fromList: params.listName,
        toList: params.listName,
      });
    },
    [user],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  });
}

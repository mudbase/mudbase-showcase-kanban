import { useCallback } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient } from "@/api/client";
import { boardListSchema, activityEntrySchema, type BoardList, type BoardCard } from "@/api/schemas";
import { LISTS_COLLECTION_ID, CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/config/env";
import { useAuth } from "@/hooks/useAuth";

/** All lists for the single shared board, ascending by column order. Mirrors web/src/hooks/useLists.ts's useBoardLists. */
export function useBoardLists() {
  return useQuery({
    queryKey: ["collection", LISTS_COLLECTION_ID, { boardId: BOARD_ID }],
    queryFn: () =>
      mudbaseClient.listDocuments(boardListSchema, LISTS_COLLECTION_ID, {
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
  void queryClient.invalidateQueries({ queryKey: ["collection", LISTS_COLLECTION_ID] });
  void queryClient.invalidateQueries({ queryKey: ["collection", ACTIVITY_COLLECTION_ID] });
}

/** Owner-only: creates a new column at the end of the board. */
export function useCreateList() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async ({ name, position }: { name: string; position: number }): Promise<BoardList> => {
      const { actorId, actorName } = actorFields(user);
      const created = await mudbaseClient.createDocument(boardListSchema, LISTS_COLLECTION_ID, {
        boardId: BOARD_ID,
        name,
        position,
      });
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "created_list",
        toList: name,
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

/** Owner-only: renames a column. */
export function useRenameList() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async ({ list, newName }: { list: BoardList; newName: string }): Promise<BoardList> => {
      const { actorId, actorName } = actorFields(user);
      const updated = await mudbaseClient.updateDocument(boardListSchema, LISTS_COLLECTION_ID, list._id, {
        name: newName,
      });
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "renamed_list",
        fromList: list.name,
        toList: newName,
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

/** Owner-only: swaps this list's position with an adjacent one (left/right reorder). */
export function useReorderList() {
  const queryClient = useQueryClient();

  const mutate = useCallback(async ({ list, neighbor }: { list: BoardList; neighbor: BoardList }): Promise<void> => {
    await Promise.all([
      mudbaseClient.updateDocument(boardListSchema, LISTS_COLLECTION_ID, list._id, { position: neighbor.position }),
      mudbaseClient.updateDocument(boardListSchema, LISTS_COLLECTION_ID, neighbor._id, { position: list.position }),
    ]);
  }, []);

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["collection", LISTS_COLLECTION_ID] }),
  });
}

/** Owner-only: deletes a column and cascades to every card inside it — a list's cards have
 * nowhere else to live once the column is gone, there's no "uncategorized" list to fall back to. */
export function useDeleteList() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async ({ list, cardsInList }: { list: BoardList; cardsInList: BoardCard[] }): Promise<void> => {
      const { actorId, actorName } = actorFields(user);
      await Promise.all(cardsInList.map((card) => mudbaseClient.deleteDocument(CARDS_COLLECTION_ID, card._id)));
      await mudbaseClient.deleteDocument(LISTS_COLLECTION_ID, list._id);
      await mudbaseClient.createDocument(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "deleted_list",
        fromList: list.name,
      });
    },
    [user],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => {
      invalidateBoard(queryClient);
      void queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] });
    },
  });
}

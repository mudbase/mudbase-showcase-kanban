# frozen_string_literal: true

# The board page: every list (column) with its cards, grouped client-side by `listId` from one
# query per collection (not one per column) - mirrors the reference web app's `BoardView`. Every
# role must sign in to see this - there is no anonymous/guest read on this project (see
# plan/build-plan.md "Auth Model").
class App < Sinatra::Base
  get "/" do
    require_login!

    @lists = with_access_token { |token| Mudbase::ListsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id) }
    @cards = with_access_token { |token| Mudbase::CardsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id) }
    @cards_by_list = @cards.group_by { |card| card[:listId] }

    erb :"board/index"
  end

  helpers do
    # `{ actorId:, actorName: }` for the signed-in user, written onto every activity row this
    # app creates - mirrors the reference web app's `actorFields()` in `src/hooks/useLists.ts`/
    # `useCards.ts`. Callers are always behind `require_login!`/`require_owner!`/
    # `require_write_access!`, so `@current_user` is guaranteed present.
    def actor_fields
      {
        actorId: @current_user[:id],
        actorName: "#{@current_user[:firstName]} #{@current_user[:lastName]}".strip,
      }
    end

    # Next `position` value to append at the end of a given list's cards - 0 for an empty list,
    # otherwise one past the current maximum. Used both for "new card" and "move to..." (both
    # append to the end of the target column, per plan/build-plan.md).
    def next_card_position(list_id, cards_by_list)
      cards = cards_by_list[list_id] || []
      return 0 if cards.empty?

      cards.map { |c| c[:position].to_i }.max + 1
    end

    def next_list_position(lists)
      return 0 if lists.empty?

      lists.map { |l| l[:position].to_i }.max + 1
    end
  end
end

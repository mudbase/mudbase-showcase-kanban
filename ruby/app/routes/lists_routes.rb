# frozen_string_literal: true

# List (column) restructuring - owner only, per the RBAC matrix in plan/build-plan.md.
# `require_owner!` is this app's own server-side gate, checked before any Mudbase call is even
# attempted; Mudbase's collection permissions are the real enforcement boundary underneath it
# (verified live - see plan/build-plan.md "Live smoke test results" for a member/viewer raw
# write attempt against `lists` that the UI never exposes a button for, and that gets rejected
# independently of this app).
class App < Sinatra::Base
  LIST_NAME_MAX_LENGTH = 60

  post "/lists" do
    require_owner!

    name = params["name"].to_s.strip
    if name.empty? || name.length > LIST_NAME_MAX_LENGTH
      flash_error(name.empty? ? "List name is required." : "Keep the list name under #{LIST_NAME_MAX_LENGTH} characters.")
      redirect "/"
    end

    with_access_token do |token|
      lists = Mudbase::ListsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
      Mudbase::ListsRepo.create!(
        access_token: token,
        attributes: { boardId: Mudbase::Config.board_id, name: name, position: next_list_position(lists) },
      )
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: { boardId: Mudbase::Config.board_id, action: "created_list", toList: name, **actor_fields },
      )
    end

    flash_notice("List \"#{name}\" was added.")
    redirect "/"
  end

  post "/lists/:id/rename" do
    require_owner!

    new_name = params["name"].to_s.strip
    if new_name.empty? || new_name.length > LIST_NAME_MAX_LENGTH
      flash_error(new_name.empty? ? "List name is required." : "Keep the list name under #{LIST_NAME_MAX_LENGTH} characters.")
      redirect "/"
    end

    with_access_token do |token|
      list = Mudbase::ListsRepo.find(access_token: token, id: params["id"])
      halt 404, erb(:"errors/not_found", layout: :layout) unless list
      next if new_name == list[:name]

      Mudbase::ListsRepo.update!(access_token: token, id: list[:_id], attributes: { name: new_name })
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: {
          boardId: Mudbase::Config.board_id, action: "renamed_list",
          fromList: list[:name], toList: new_name, **actor_fields
        },
      )
    end

    redirect "/"
  end

  post "/lists/:id/delete" do
    require_owner!

    with_access_token do |token|
      list = Mudbase::ListsRepo.find(access_token: token, id: params["id"])
      halt 404, erb(:"errors/not_found", layout: :layout) unless list

      cards_in_list = Mudbase::CardsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
        .select { |card| card[:listId] == list[:_id] }
      cards_in_list.each { |card| Mudbase::CardsRepo.delete!(access_token: token, id: card[:_id]) }

      Mudbase::ListsRepo.delete!(access_token: token, id: list[:_id])
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: { boardId: Mudbase::Config.board_id, action: "deleted_list", fromList: list[:name], **actor_fields },
      )
    end

    flash_notice("List deleted.")
    redirect "/"
  end

  # Swaps this list's `position` with its immediate left/right neighbor - owner-only column
  # reordering, no activity entry logged (matches the reference web app's `useReorderList`,
  # which likewise only reorders `lists` and doesn't write to the activity feed).
  post "/lists/:id/move" do
    require_owner!

    direction = params["direction"]
    halt 400, "Invalid direction" unless %w[left right].include?(direction)

    with_access_token do |token|
      lists = Mudbase::ListsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
      index = lists.index { |l| l[:_id] == params["id"] }
      halt 404, erb(:"errors/not_found", layout: :layout) if index.nil?

      neighbor_index = direction == "left" ? index - 1 : index + 1
      next if neighbor_index.negative? || neighbor_index >= lists.length

      list = lists[index]
      neighbor = lists[neighbor_index]
      Mudbase::ListsRepo.update!(access_token: token, id: list[:_id], attributes: { position: neighbor[:position] })
      Mudbase::ListsRepo.update!(access_token: token, id: neighbor[:_id], attributes: { position: list[:position] })
    end

    redirect "/"
  end
end

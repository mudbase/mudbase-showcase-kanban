# frozen_string_literal: true

# Card CRUD + movement - owner and member (viewer is read-only), per the RBAC matrix in
# plan/build-plan.md. `require_write_access!` is this app's own server-side gate, checked before
# any Mudbase call is even attempted; Mudbase's collection permissions are the real enforcement
# boundary underneath it (verified live - see plan/build-plan.md "Live smoke test results" for a
# viewer raw write attempt against `cards` that the UI never exposes a button for).
class App < Sinatra::Base
  TITLE_MAX_LENGTH = 120
  DESCRIPTION_MAX_LENGTH = 2000

  get "/lists/:list_id/cards/new" do
    require_write_access!

    @list = with_access_token { |token| Mudbase::ListsRepo.find(access_token: token, id: params["list_id"]) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless @list

    @card = { title: "", description: "", assignee_name: "" }
    @form_action = "/cards"
    @form_title = "Add card to #{@list[:name]}"
    erb :"cards/form"
  end

  post "/cards" do
    require_write_access!

    list_id = params["list_id"]
    list = with_access_token { |token| Mudbase::ListsRepo.find(access_token: token, id: list_id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless list

    values = extract_card_form(params)
    errors = validate_card_form(values)
    if errors.any?
      @list = list
      @card = values
      @form_action = "/cards"
      @form_title = "Add card to #{list[:name]}"
      show_error_now(errors.join(" "))
      halt erb(:"cards/form")
    end

    with_access_token do |token|
      cards = Mudbase::CardsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
      position = next_card_position(list_id, cards.group_by { |c| c[:listId] })
      Mudbase::CardsRepo.create!(
        access_token: token,
        attributes: card_attributes(values).merge(
          boardId: Mudbase::Config.board_id,
          listId: list_id,
          position: position,
          createdById: @current_user[:id],
          createdByName: "#{@current_user[:firstName]} #{@current_user[:lastName]}".strip,
        ),
      )
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: {
          boardId: Mudbase::Config.board_id, action: "created_card",
          cardTitle: values[:title], toList: list[:name], **actor_fields
        },
      )
    end

    flash_notice("Card added.")
    redirect "/"
  end

  get "/cards/:id/edit" do
    require_write_access!

    card = with_access_token { |token| Mudbase::CardsRepo.find(access_token: token, id: params["id"]) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless card

    @list = with_access_token { |token| Mudbase::ListsRepo.find(access_token: token, id: card[:listId]) }
    @card = card_to_form_values(card)
    @form_action = "/cards/#{card[:_id]}"
    @form_title = "Edit card"
    erb :"cards/form"
  end

  post "/cards/:id" do
    require_write_access!

    card = with_access_token { |token| Mudbase::CardsRepo.find(access_token: token, id: params["id"]) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless card

    values = extract_card_form(params)
    errors = validate_card_form(values)
    if errors.any?
      @list = with_access_token { |token| Mudbase::ListsRepo.find(access_token: token, id: card[:listId]) }
      @card = values
      @form_action = "/cards/#{card[:_id]}"
      @form_title = "Edit card"
      show_error_now(errors.join(" "))
      halt erb(:"cards/form")
    end

    # Not itself logged to the activity feed - only creation, movement, and deletion are (see
    # plan/build-plan.md), matching the reference web app's `useUpdateCard`.
    with_access_token do |token|
      Mudbase::CardsRepo.update!(access_token: token, id: card[:_id], attributes: card_attributes(values))
    end

    flash_notice("Card updated.")
    redirect "/"
  end

  post "/cards/:id/delete" do
    require_write_access!

    with_access_token do |token|
      card = Mudbase::CardsRepo.find(access_token: token, id: params["id"])
      halt 404, erb(:"errors/not_found", layout: :layout) unless card

      list = Mudbase::ListsRepo.find(access_token: token, id: card[:listId])
      Mudbase::CardsRepo.delete!(access_token: token, id: card[:_id])
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: {
          boardId: Mudbase::Config.board_id, action: "deleted_card",
          cardTitle: card[:title], fromList: list && list[:name], **actor_fields
        },
      )
    end

    flash_notice("Card deleted.")
    redirect "/"
  end

  # Swaps this card's `position` with the sibling directly above/below it in the same column.
  # Still logs a `moved` activity entry with `fromList === toList`, per the task's "every
  # move...appends an activity entry" requirement - mirrors the reference web app's
  # `useReorderCardInList`.
  post "/cards/:id/move_up" do
    require_write_access!
    reorder_card_in_list(params["id"], :up)
    redirect "/"
  end

  post "/cards/:id/move_down" do
    require_write_access!
    reorder_card_in_list(params["id"], :down)
    redirect "/"
  end

  # Cross-list move: writes `listId`+`position` (appended to the end of the target column) and
  # logs a `moved` activity entry - mirrors the reference web app's `useMoveCardToList`.
  post "/cards/:id/move" do
    require_write_access!

    target_list_id = params["list_id"].to_s
    with_access_token do |token|
      card = Mudbase::CardsRepo.find(access_token: token, id: params["id"])
      halt 404, erb(:"errors/not_found", layout: :layout) unless card
      next if target_list_id.empty? || target_list_id == card[:listId]

      from_list = Mudbase::ListsRepo.find(access_token: token, id: card[:listId])
      to_list = Mudbase::ListsRepo.find(access_token: token, id: target_list_id)
      halt 404, erb(:"errors/not_found", layout: :layout) unless to_list

      cards = Mudbase::CardsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
      new_position = next_card_position(target_list_id, cards.group_by { |c| c[:listId] })

      Mudbase::CardsRepo.update!(access_token: token, id: card[:_id], attributes: { listId: target_list_id, position: new_position })
      Mudbase::ActivityRepo.create!(
        access_token: token,
        attributes: {
          boardId: Mudbase::Config.board_id, action: "moved", cardTitle: card[:title],
          fromList: from_list && from_list[:name], toList: to_list[:name], **actor_fields
        },
      )
    end

    redirect "/"
  end

  helpers do
    def extract_card_form(params)
      {
        title: params["title"].to_s.strip,
        description: params["description"].to_s.strip,
        assignee_name: params["assignee_name"].to_s.strip,
      }
    end

    def card_to_form_values(card)
      { title: card[:title].to_s, description: card[:description].to_s, assignee_name: card[:assigneeName].to_s }
    end

    def validate_card_form(values)
      errors = []
      errors << "Title is required." if values[:title].empty?
      errors << "Keep the title under #{TITLE_MAX_LENGTH} characters." if values[:title].length > TITLE_MAX_LENGTH
      if values[:description].length > DESCRIPTION_MAX_LENGTH
        errors << "Keep the description under #{DESCRIPTION_MAX_LENGTH} characters."
      end
      errors
    end

    # `assigneeId` is validated server-side as an ObjectId reference (see
    # lib/mudbase/pseudo_object_id.rb) - an empty string fails that check the same way an
    # invalid slug would ("Invalid ObjectId format for assigneeId"). `nil` is the value that
    # actually clears it; never send "" here (verified live by the reference web app's own
    # build - see its plan/build-plan.md).
    def card_attributes(values)
      assignee_present = !values[:assignee_name].empty?
      {
        title: values[:title],
        description: values[:description],
        assigneeId: assignee_present ? Mudbase::PseudoObjectId.generate(values[:assignee_name]) : nil,
        assigneeName: assignee_present ? values[:assignee_name] : nil,
      }
    end

    def reorder_card_in_list(card_id, direction)
      with_access_token do |token|
        card = Mudbase::CardsRepo.find(access_token: token, id: card_id)
        halt 404, erb(:"errors/not_found", layout: :layout) unless card

        list = Mudbase::ListsRepo.find(access_token: token, id: card[:listId])
        siblings = Mudbase::CardsRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id)
          .select { |c| c[:listId] == card[:listId] }
          .sort_by { |c| c[:position].to_i }

        index = siblings.index { |c| c[:_id] == card[:_id] }
        neighbor_index = direction == :up ? index - 1 : index + 1
        next if index.nil? || neighbor_index.negative? || neighbor_index >= siblings.length

        neighbor = siblings[neighbor_index]
        Mudbase::CardsRepo.update!(access_token: token, id: card[:_id], attributes: { position: neighbor[:position] })
        Mudbase::CardsRepo.update!(access_token: token, id: neighbor[:_id], attributes: { position: card[:position] })
        Mudbase::ActivityRepo.create!(
          access_token: token,
          attributes: {
            boardId: Mudbase::Config.board_id, action: "moved", cardTitle: card[:title],
            fromList: list && list[:name], toList: list && list[:name], **actor_fields
          },
        )
      end
    end
  end
end

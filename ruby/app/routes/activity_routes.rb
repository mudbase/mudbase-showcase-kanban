# frozen_string_literal: true

# Full reverse-chronological activity feed - readable by all three roles.
class App < Sinatra::Base
  get "/activity" do
    require_login!

    @entries = with_access_token { |token| Mudbase::ActivityRepo.for_board(access_token: token, board_id: Mudbase::Config.board_id) }
    erb :"activity/index"
  end
end

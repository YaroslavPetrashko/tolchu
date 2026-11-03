module NavigationHelpers
  def path_to(page_name)
    case page_name
    when "the feed" then root_path
    when "the sign up page" then new_registration_path
    when "the sign in page" then new_session_path
    when "my wallet" then wallet_path
    when "my studio" then studio_markets_path
    when "the new market page" then new_studio_market_path
    when "the how it works page" then how_it_works_path
    else raise ArgumentError, "No path mapped for #{page_name.inspect}. Add it to features/support/paths.rb"
    end
  end
end

World(NavigationHelpers)

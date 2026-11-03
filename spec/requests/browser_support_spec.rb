require "rails_helper"

RSpec.describe "Browser support" do
  user_agents = {
    "iOS 18 Safari" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
    "iOS 17.1 Safari" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
    "iOS 16.6 Safari" => "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
    "Android Chrome 118" => "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36",
    "Safari 15.6" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Safari/605.1.15",
    "Internet Explorer 11" => "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko"
  }

  [ "iOS 18 Safari", "iOS 17.1 Safari", "iOS 16.6 Safari", "Android Chrome 118" ].each do |browser|
    it "serves the feed to #{browser}" do
      get root_path, headers: { "User-Agent" => user_agents.fetch(browser) }
      expect(response).to have_http_status(:ok)
    end
  end

  [ "Safari 15.6", "Internet Explorer 11" ].each do |browser|
    it "shows the unsupported-browser page to #{browser}" do
      get root_path, headers: { "User-Agent" => user_agents.fetch(browser) }
      expect(response).to have_http_status(:not_acceptable)
    end
  end
end

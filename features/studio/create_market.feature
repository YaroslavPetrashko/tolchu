Feature: Post a market from a clip
  As a creator who films exciting moments
  I want to turn a clip into a "what happens next?" market
  So that my viewers can bet on it and I earn a share of the fee

  Background:
    Given I am signed in as "StuntLab"
    And I am on my studio
    When I follow "New market"

  Scenario: Publishing a market
    When I fill in the market form with:
      | Question                     | Will she stick the landing?      |
      | Clip URL                     | https://cdn.example.com/flip.mp4 |
      | Freeze the clip at (seconds) | 4.5                              |
      | Outcome 1                    | Sticks it                        |
      | Outcome 2                    | Wipes out                        |
      | Outcome 3                    | Bails before takeoff             |
    And I select "15 minutes" from "Betting window"
    And I press "Publish market"
    Then I should see "Your market is live! Betting closes 15 minutes from now."
    And my studio should list "Will she stick the landing?" as "Live"
    And the feed should include "Will she stick the landing?" with outcomes "Sticks it, Wipes out, Bails before takeoff"

  Scenario: A market needs at least two outcomes
    When I fill in the market form with:
      | Question  | Will she stick the landing?      |
      | Clip URL  | https://cdn.example.com/flip.mp4 |
      | Outcome 1 | Sticks it                        |
    And I press "Publish market"
    Then I should see "Outcomes must have between 2 and 4 options (you have 1)"

  Scenario: A market needs a playable clip link
    When I fill in the market form with:
      | Question  | Will she stick the landing? |
      | Clip URL  | my-clip.mp4                 |
      | Outcome 1 | Sticks it                   |
      | Outcome 2 | Wipes out                   |
    And I press "Publish market"
    Then I should see "Clip URL must be an http(s) link to a video file"

  Scenario: Outcomes have to be different from each other
    When I fill in the market form with:
      | Question  | Will she stick the landing?      |
      | Clip URL  | https://cdn.example.com/flip.mp4 |
      | Outcome 1 | Sticks it                        |
      | Outcome 2 | sticks it                        |
    And I press "Publish market"
    Then I should see "Outcomes must all be different"

  Scenario: A market needs a question
    When I fill in the market form with:
      | Clip URL  | https://cdn.example.com/flip.mp4 |
      | Outcome 1 | Sticks it                        |
      | Outcome 2 | Wipes out                        |
    And I press "Publish market"
    Then I should see "Question can't be blank"

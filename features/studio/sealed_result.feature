Feature: Pay predictions on a sealed clip result
  As a creator posting a recorded clip
  I want the answer I seal when publishing to settle the market
  So that bettors get paid without me choosing a different result later

  Background:
    Given I am signed in as "StuntLab"
    When I go to the new market page
    And I fill in the market form with:
      | Question                     | Will the sealed trick land?      |
      | Clip URL                     | https://cdn.example.com/flip.mp4 |
      | Freeze the clip at (seconds) | 4.5                              |
      | Outcome 1                    | Lands                            |
      | Outcome 2                    | Bails                            |
    And I select "Outcome 1" from "What actually happens?"
    And I select "1 minute" from "Betting window"
    And I press "Publish market"
    Given "alice" has predicted "Lands" with 100 credits on "Will the sealed trick land?"
    And "bob" has predicted "Bails" with 100 credits on "Will the sealed trick land?"

  Scenario: The sealed answer pays out when the betting window ends
    Then I should see "The sealed result settles automatically when betting closes."
    When 2 minutes pass
    And I go to my studio
    Then my studio should list "Will the sealed trick land?" as "Settled"
    And "alice" should have 1,090 credits
    And "bob" should have 900 credits
    And my balance should be 1,005 credits
    And my studio should show a reward of 5 credits for "Will the sealed trick land?"

  Scenario: Locking early pays the sealed answer without another result selection
    When I lock betting on "Will the sealed trick land?" from my studio
    Then I should see "The sealed result will settle automatically."
    And my studio should list "Will the sealed trick land?" as "Settled"
    And I should not see a "Declare result" button
    And "alice" should have 1,090 credits
    And "bob" should have 900 credits
    And my balance should be 1,005 credits

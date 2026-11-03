Feature: Predict what happens next
  As a fan watching a clip
  I want to back an outcome with a single tap and a small stake
  So that I can win credits from the pool without deep betting knowledge

  Background:
    Given a creator "StuntLab" exists
    And "StuntLab" posted "Will he land the kickflip?" with outcomes "Lands it" and "Bails"
    And I am signed in as "fan"

  Scenario: Placing a prediction from the feed
    When I predict "Lands it" with 50 credits on "Will he land the kickflip?"
    Then I should see "Prediction locked in: Lands it for 50 credits."
    And my balance should be 950 credits
    And the market "Will he land the kickflip?" should have 50 credits in the pool from 1 prediction
    And the market "Will he land the kickflip?" should say "You picked Lands it for 50 credits"

  Scenario: Placing a prediction from the clip's own page
    When I predict "Bails" with 25 credits on "Will he land the kickflip?" from its page
    Then I should see "Prediction locked in: Bails for 25 credits."
    And I should see "Pool breakdown"
    And my balance should be 975 credits

  Scenario: Stakes are capped at 100 credits per market
    When I predict "Lands it" with 150 credits on "Will he land the kickflip?"
    Then I should see "Stake must be less than or equal to 100"
    And my balance should be 1,000 credits

  Scenario: I can't stake more credits than I have
    Given my balance is 30 credits
    When I predict "Bails" with 50 credits on "Will he land the kickflip?"
    Then I should see "You don't have enough credits for that stake (balance: 30)"
    And my balance should be 30 credits

  Scenario: I have to pick an outcome
    When I stake 25 credits on "Will he land the kickflip?" without picking an outcome
    Then I should see "Pick one of the outcomes before placing your bet"

  Scenario: One prediction per market
    Given I have predicted "Lands it" with 20 credits on "Will he land the kickflip?"
    When I go to the feed
    Then the market "Will he land the kickflip?" should say "You picked Lands it for 20 credits"
    And the market "Will he land the kickflip?" should not offer a "Place bet" button

  Scenario: Betting closes the moment the market locks, even on a page I already had open
    Given "Will he land the kickflip?" locks in 5 minutes
    And I am on the feed
    When 6 minutes pass
    And I submit "Lands it" with 10 credits on "Will he land the kickflip?" from the page I already have open
    Then I should see "Betting is closed for this market"
    And my balance should be 1,000 credits

  Scenario: Creators can't bet on their own clips
    Given I am signed in as "StuntLab"
    When I go to the feed
    Then the market "Will he land the kickflip?" should say "You created this market, so you can't bet on it."
    And the market "Will he land the kickflip?" should not offer a "Place bet" button

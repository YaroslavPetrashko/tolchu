Feature: Browse the clip feed
  As a casual fan scrolling short videos
  I want every clip to ask a simple "what happens next?" question
  So that I have all the context I need before I predict

  Background:
    Given a creator "StuntLab" exists

  Scenario: Each clip shows its question, outcomes, and how the pool is split
    Given "StuntLab" posted "Will he land the kickflip?" with outcomes "Lands it" and "Bails"
    And "alice" has predicted "Lands it" with 60 credits on "Will he land the kickflip?"
    And "bob" has predicted "Bails" with 40 credits on "Will he land the kickflip?"
    When I go to the feed
    Then the market "Will he land the kickflip?" should be marked "Live"
    And the market "Will he land the kickflip?" should say "@StuntLab asks"
    And the market "Will he land the kickflip?" should have 100 credits in the pool from 2 predictions
    And the market "Will he land the kickflip?" should show "Lands it" with 60% of the pool
    And the market "Will he land the kickflip?" should show "Bails" with 40% of the pool

  Scenario: Markets closing soonest come first
    Given "StuntLab" posted "Closing later?" that locks in 120 minutes
    And "StuntLab" posted "Closing sooner?" that locks in 5 minutes
    When I go to the feed
    Then I should see "Closing sooner?" before "Closing later?"

  Scenario: Betting closes on its own when the window ends
    Given "StuntLab" posted "Will the buzzer beater go in?" that locks in 1 minute
    When 2 minutes pass
    And I go to the feed
    Then the market "Will the buzzer beater go in?" should be marked "Locked"
    And the market "Will the buzzer beater go in?" should say "Betting closed. Waiting for the result"

  Scenario: Settled markets show the result
    Given "StuntLab" posted "Penalty: left or right?" with outcomes "Left" and "Right"
    And "Penalty: left or right?" has been settled as "Left"
    When I go to the feed
    Then the market "Penalty: left or right?" should be marked "Settled"
    And the market "Penalty: left or right?" should say "Result: Left"

  Scenario: Cancelled markets are hidden from the feed
    Given "StuntLab" posted "Will it rain on the parade?" with outcomes "Rain" and "Shine"
    And "Will it rain on the parade?" has been cancelled
    When I go to the feed
    Then I should not see "Will it rain on the parade?"

  Scenario: Guests can watch, but have to sign in to predict
    Given "StuntLab" posted "Will he land the kickflip?" with outcomes "Lands it" and "Bails"
    When I go to the feed
    Then the market "Will he land the kickflip?" should offer "Sign in to predict"
    And I should not see a "Place bet" button

  Scenario: An empty feed invites people to post the first clip
    When I go to the feed
    Then I should see "No clips yet"
    And I should see "Post a market"

  Scenario: Opening a clip shows the full pool breakdown
    Given "StuntLab" posted "Will he land the kickflip?" with outcomes "Lands it" and "Bails"
    And "alice" has predicted "Bails" with 25 credits on "Will he land the kickflip?"
    When I go to the feed
    And I follow "Will he land the kickflip?"
    Then I should see "Pool breakdown"
    And I should see "Posted by @StuntLab"

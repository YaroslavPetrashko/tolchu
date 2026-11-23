@javascript
Feature: Watch a clip and bet in a real browser
  As a fan watching the feed on my phone
  I want the clip to stop before the action and the bet pad to respond as I use it
  So that I predict with full context, never see the result early, and never lose my place

  Background:
    Given a creator "StuntLab" exists
    And "StuntLab" posted a playable clip "Will he land the kickflip?" with outcomes "Lands it" and "Bails" that freezes at 1.0 second

  Scenario: The clip freezes right before the action
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should freeze at 1.0 second
    And the clip for "Will he land the kickflip?" should still be frozen a moment later

  Scenario: A clip with no freeze point stops at its halfway mark
    Given the clip for "Will he land the kickflip?" has no freeze point
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should freeze at 1.5 seconds
    And the clip for "Will he land the kickflip?" should still be frozen a moment later

  Scenario: A freeze point past the end of the clip also falls back to halfway
    Given the clip for "Will he land the kickflip?" has a freeze point of 10.0 seconds
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should freeze at 1.5 seconds

  Scenario: Replaying a clip with no freeze point stops at halfway again
    Given the clip for "Will he land the kickflip?" has no freeze point
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should freeze at 1.5 seconds
    When I replay the clip for "Will he land the kickflip?"
    Then the clip for "Will he land the kickflip?" should freeze at 1.5 seconds

  Scenario: Once betting has closed the clip follows the same rule, with no way to bet
    Given the clip for "Will he land the kickflip?" has no freeze point
    And betting has closed on "Will he land the kickflip?"
    And I am signed in as "fan"
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should freeze at 1.5 seconds
    And the clip for "Will he land the kickflip?" should still be frozen a moment later
    And "Will he land the kickflip?" should not take bets

  Scenario: A settled clip plays through to the ending
    Given the clip for "Will he land the kickflip?" has no freeze point
    And "Will he land the kickflip?" has been settled as "Lands it"
    When I go to the feed
    Then the clip for "Will he land the kickflip?" should play through to the end

  Scenario: Betting closes on screen when the countdown hits zero
    Given I am signed in as "fan"
    And "Will he land the kickflip?" locks in 4 seconds
    When I open the feed and keep it open
    Then betting on "Will he land the kickflip?" should close on screen when the countdown runs out
    And the page should not have reloaded

  Scenario: Raising my stake updates what each outcome would pay
    Given "alice" has predicted "Lands it" with 60 credits on "Will he land the kickflip?"
    And "bob" has predicted "Bails" with 40 credits on "Will he land the kickflip?"
    And I am signed in as "fan"
    When I open the feed and keep it open
    Then "Bails" on "Will he land the kickflip?" should show "wins 21" at "×2.10"
    When I raise my stake on "Will he land the kickflip?" to 15 credits with the arrow keys
    Then the bet button on "Will he land the kickflip?" should show a stake of 15
    And "Bails" on "Will he land the kickflip?" should show "wins 30" at "×2.00"
    And "Lands it" on "Will he land the kickflip?" should show "wins 22" at "×1.47"

  Scenario: Flicking toward an outcome places the bet without a page load
    Given I am signed in as "fan"
    When I open the feed and keep it open
    And I flick the bet button toward "Lands it" on "Will he land the kickflip?"
    Then the card for "Will he land the kickflip?" should show my pending bet of 10 credits on "Lands it"
    And the balance in my menu should have updated to 990 credits
    And the page should not have reloaded
    And "fan" should have 990 credits

  Scenario: Betting with the keyboard instead of a flick
    Given I am signed in as "fan"
    When I open the feed and keep it open
    And I pick "Bails" on "Will he land the kickflip?" and press Enter on the bet button
    Then the card for "Will he land the kickflip?" should show my pending bet of 10 credits on "Bails"
    And the page should not have reloaded

  Scenario: Pressing Enter before picking an outcome asks me to pick one
    Given I am signed in as "fan"
    When I open the feed and keep it open
    And I press Enter on the bet button for "Will he land the kickflip?" without picking an outcome
    Then the market "Will he land the kickflip?" should hint "Pick an outcome first"
    And "fan" should have 1,000 credits

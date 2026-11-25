@javascript
Feature: Recover a prediction pad and spend only available credits
  As a fan watching clips
  I want to correct my stake and reuse credits already in my prediction
  So that I can place or change a bet without reloading the feed

  Background:
    Given a creator "PadCreator" exists
    And "PadCreator" posted a playable clip "First pad?" with outcomes "Yes" and "No" that freezes at 1.0 second
    And "PadCreator" posted a playable clip "Second pad?" with outcomes "Yes" and "No" that freezes at 1.0 second
    And I am signed in as "padfan"

  Scenario: A small balance starts with an affordable stake
    Given my balance is 3 credits
    When I open the recovery feed
    Then the pad for "First pad?" should allow at most 3 credits with stake "3"
    When I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 3 credits on "Yes"
    And the balance in my menu should have updated to 0 credits
    And exactly 1 prediction request should have been sent for "First pad?"

  Scenario: An empty wallet cannot place a prediction
    Given my balance is 0 credits
    When I open the recovery feed
    Then the pad for "First pad?" should allow at most 0 credits with stake "0"
    And the pad for "First pad?" should be disabled without sending a prediction
    And the pad for "First pad?" should show finite odds or an unavailable estimate
    And I should see "no credits"

  Scenario Outline: Correcting an invalid stake submits once
    When I open the recovery feed
    And I type stake "<invalid>" into the pad for "First pad?"
    And I try to raise the invalid stake on "First pad?"
    And I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the pad for "First pad?" should keep invalid stake "<invalid>" and remain usable
    And the pad for "First pad?" should show finite odds or an unavailable estimate
    When I type stake "20" into the pad for "First pad?"
    And I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 20 credits on "Yes"
    And exactly 1 prediction request should have been sent for "First pad?"
    And the balance in my menu should have updated to 980 credits

    Examples:
      | invalid |
      | 101     |
      |         |
      | 1.5     |

  Scenario: A lost connection does not leave the pad waiting forever
    When I open the recovery feed
    And I type stake "20" into the pad for "First pad?"
    And the next prediction request for "First pad?" loses its connection
    And I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the pad for "First pad?" should recover from the failed request
    When I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 20 credits on "Yes"
    And exactly 2 prediction requests should have been sent for "First pad?"
    And the balance in my menu should have updated to 980 credits
    And the page should not have reloaded

  Scenario: Spending on one clip updates another loaded pad
    Given my balance is 30 credits
    When I open the recovery feed
    And I type stake "30" into the pad for "Second pad?"
    And I type stake "20" into the pad for "First pad?"
    And I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 20 credits on "Yes"
    And the pad for "Second pad?" should allow at most 10 credits with stake "10"
    When I try to raise the stake above the budget on "Second pad?"
    Then the pad for "Second pad?" should allow at most 10 credits with stake "10"
    When I pick "No" on "Second pad?" and press Enter on the bet button
    Then the card for "Second pad?" should show my pending bet of 10 credits on "No"
    And the balance in my menu should have updated to 0 credits
    And exactly 1 prediction request should have been sent for "Second pad?"
    And the page should not have reloaded

  Scenario: A wallet update does not silently turn an invalid stake into a valid one
    Given my balance is 30 credits
    When I open the recovery feed
    And I type stake "1.5" into the pad for "Second pad?"
    And I type stake "20" into the pad for "First pad?"
    And I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 20 credits on "Yes"
    And the pad for "Second pad?" should allow at most 10 credits with stake "1.5"
    And the pad for "Second pad?" should keep invalid stake "1.5" and remain usable
    When I type stake "5" into the pad for "Second pad?"
    And I pick "No" on "Second pad?" and press Enter on the bet button
    Then the card for "Second pad?" should show my pending bet of 5 credits on "No"
    And the balance in my menu should have updated to 5 credits

  Scenario: Changing a prediction reuses its original stake without creating credits
    Given my balance is 30 credits
    And I have predicted "Yes" with 20 credits on "First pad?"
    When I open the recovery feed
    And I open my prediction editor for "First pad?"
    Then the pad for "First pad?" should allow at most 30 credits with stake "20"
    When I type stake "25" into the pad for "First pad?"
    Then the pad for "First pad?" should allow at most 30 credits with stake "25"
    When I type stake "30" into the pad for "First pad?"
    And I pick "No" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 30 credits on "No"
    And the balance in my menu should have updated to 0 credits
    And the pad for "Second pad?" should be disabled without sending a prediction
    When I open my prediction editor for "First pad?"
    Then the pad for "First pad?" should allow at most 30 credits with stake "30"
    When I pick "Yes" on "First pad?" and press Enter on the bet button
    Then the card for "First pad?" should show my pending bet of 30 credits on "Yes"
    And the balance in my menu should have updated to 0 credits
    And exactly 2 prediction requests should have been sent for "First pad?"
    And my predictions and wallet should still total 30 credits
    And the page should not have reloaded

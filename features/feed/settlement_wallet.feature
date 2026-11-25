@javascript
Feature: See my wallet update when a clip settles
  As a fan staying in the feed
  I want settled winnings and refunds to update my wallet immediately
  So that the credits I can spend agree with the result on my card

  Background:
    Given a creator "StuntLab" exists
    And "StuntLab" posted a playable clip "Will the recorded trick land?" with outcomes "Lands" and "Bails" that freezes at 1.0 second
    And the recorded result of "Will the recorded trick land?" is sealed as "Lands"
    And "fan" has predicted "Lands" with 20 credits on "Will the recorded trick land?"

  Scenario: A winning prediction updates the menu without leaving the feed
    Given "opponent" has predicted "Bails" with 20 credits on "Will the recorded trick land?"
    And I am signed in as "fan"
    And "Will the recorded trick land?" locks in 4 seconds
    When I open the feed and keep it open
    Then the sealed clip "Will the recorded trick land?" should settle on screen
    And the balance in my menu should have updated to 1,018 credits
    And the page should not have reloaded
    When I open the account menu
    Then my balance should be 1,018 credits

  Scenario: A no-contest refund restores my menu balance in place
    Given I am signed in as "fan"
    And "Will the recorded trick land?" locks in 4 seconds
    When I open the feed and keep it open
    Then the sealed clip "Will the recorded trick land?" should settle on screen
    And the balance in my menu should have updated to 1,000 credits
    And the page should not have reloaded
    When I open the account menu
    Then my balance should be 1,000 credits

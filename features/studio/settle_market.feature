Feature: Lock and settle a market
  As a creator
  I want to lock betting right before the play and then declare what happened
  So that the pool pays out within seconds of the result

  Background:
    Given I am signed in as "StuntLab"
    And I posted "Will the trick land?" with outcomes "Lands" and "Bails"
    And "alice" has predicted "Lands" with 100 credits on "Will the trick land?"
    And "bob" has predicted "Bails" with 100 credits on "Will the trick land?"

  Scenario: Locking betting right before the play
    When I lock betting on "Will the trick land?" from my studio
    Then I should see "Betting is locked on “Will the trick land?”"
    And my studio should list "Will the trick land?" as "Locked"
    And "Will the trick land?" should no longer accept predictions

  Scenario: Declaring the result pays the winners straight away
    Given I have locked betting on "Will the trick land?"
    When I declare "Lands" as the result of "Will the trick land?"
    Then I should see "Result declared: Lands. Payouts sent!"
    And "alice" should have 1,090 credits
    And "bob" should have 900 credits
    And my balance should be 1,005 credits
    And my studio should show a reward of 5 credits for "Will the trick land?"

  Scenario: A result can't be declared while betting is still open
    When I go to my studio
    Then I should not be able to declare the result of "Will the trick land?"

  Scenario: Markets lock on their own when the betting window ends
    Given "Will the trick land?" locks in 5 minutes
    When 6 minutes pass
    And I go to my studio
    Then I should be able to declare the result of "Will the trick land?"

  Scenario: Cancelling a market refunds everyone
    When I cancel "Will the trick land?" from my studio
    Then I should see "“Will the trick land?” was cancelled and every stake was refunded."
    And "alice" should have 1,000 credits
    And "bob" should have 1,000 credits
    And my studio should list "Will the trick land?" as "Cancelled"

  Scenario: I only see and manage my own markets
    Given a creator "RivalCreator" exists
    And "RivalCreator" posted "Will the rival's trick land?" with outcomes "Yes" and "No"
    When I go to my studio
    Then I should see "Will the trick land?"
    But I should not see "Will the rival's trick land?"

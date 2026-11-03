Feature: Track my credits and predictions
  As a bettor
  I want one place that shows my balance, my open predictions, and every credit movement
  So that I always know how I'm doing

  Background:
    Given a creator "StuntLab" exists
    And "StuntLab" posted "Will he land the kickflip?" with outcomes "Lands it" and "Bails"
    And "StuntLab" posted "Will the free throw go in?" with outcomes "Swish" and "Brick"
    And I am signed in as "fan"

  Scenario: Seeing pending and settled predictions
    Given I have predicted "Lands it" with 40 credits on "Will he land the kickflip?"
    And I have predicted "Swish" with 100 credits on "Will the free throw go in?"
    And "carol" has predicted "Brick" with 100 credits on "Will the free throw go in?"
    And "Will the free throw go in?" has been settled as "Swish"
    When I go to my wallet
    Then I should see my prediction on "Will he land the kickflip?" marked "Pending"
    And I should see my prediction on "Will the free throw go in?" marked "Won +90"
    And I should see "1,050 credits"

  Scenario: Every credit movement is logged
    Given I have predicted "Lands it" with 40 credits on "Will he land the kickflip?"
    And "Will he land the kickflip?" has been cancelled
    When I go to my wallet
    Then my activity should include "Prediction on “Will he land the kickflip?”" for -40 credits
    And my activity should include "Refund for “Will he land the kickflip?”" for +40 credits
    And I should see my prediction on "Will he land the kickflip?" marked "Refunded"

  Scenario: Getting to my wallet from the balance in the navigation
    Given I am on the feed
    When I follow my balance
    Then I should be on my wallet
    And I should see "No predictions yet."

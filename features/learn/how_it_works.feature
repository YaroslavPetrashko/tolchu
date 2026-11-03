Feature: Learn how Tolchu works
  As a casual fan who finds sportsbooks intimidating
  I want a plain-English explanation of how the shared pool works
  So that I understand what I'm betting on before I stake credits

  Scenario: Reading the explainer from the feed
    Given I am on the feed
    When I follow "How it works"
    Then I should be on the how it works page
    And I should see "The house never bets against you"
    And I should see "flat 5% fee"
    And I should see "at most 100 credits per market"
    And I should see "No contest, no fee"

Feature: Sign in and out
  As a returning fan
  I want to sign in and out securely
  So that my credits and predictions stay mine

  Background:
    Given a user "regular" exists

  Scenario: Signing in with the right password
    When I sign in with "regular@example.com" and "password123"
    Then I should see "Welcome back, regular!"
    And my balance should be 1,000 credits

  Scenario: Signing in with the wrong password
    When I sign in with "regular@example.com" and "not-my-password"
    Then I should see "That email and password don't match."
    And I should not be signed in

  Scenario: Signing out
    Given I am signed in as "regular"
    When I press "Sign out"
    Then I should see "You've been signed out."
    And I should not be signed in

  Scenario: My wallet requires an account, and I land back there after signing in
    When I go to my wallet
    Then I should be on the sign in page
    And I should see "Sign in to keep going."
    When I sign in with "regular@example.com" and "password123" on this page
    Then I should be on my wallet

  Scenario: The creator studio requires an account
    When I go to my studio
    Then I should be on the sign in page

Feature: Sign up for an account
  As a casual sports fan who has never placed a bet
  I want to create an account in seconds and get free credits
  So that I can start predicting clips without risking real money

  Background:
    Given I am on the sign up page

  Scenario: Signing up gives me 1,000 starting credits
    When I sign up as "rookie" with email "rookie@example.com" and password "password123"
    Then my balance should be 1,000 credits
    And my wallet should show "Welcome bonus" for +1,000 credits

  Scenario: Usernames are unique, ignoring capitalisation
    Given a user "rookie" exists
    When I sign up as "Rookie" with email "someone@example.com" and password "password123"
    Then I should see "Username has already been taken"
    And I should not be signed in

  Scenario: Password confirmation has to match
    When I sign up as "rookie" with email "rookie@example.com", password "password123" and confirmation "password124"
    Then I should see "Password confirmation doesn't match Password"

  Scenario: Passwords need at least 8 characters
    When I sign up as "rookie" with email "rookie@example.com" and password "short"
    Then I should see "Password is too short (minimum is 8 characters)"

  Scenario: Usernames can only use letters, numbers, and underscores
    When I sign up as "rookie fan!" with email "rookie@example.com" and password "password123"
    Then I should see "Username can only use letters, numbers, and underscores"

  Scenario: Throwaway email addresses are refused
    When I sign up as "rookie" with email "rookie@mailinator.com" and password "password123"
    Then I should see "Email can't be a temporary or disposable address"
    And I should not be signed in

  Scenario: Addresses that aren't real emails are refused
    When I sign up as "rookie" with email "rookie@gmail" and password "password123"
    Then I should see "Email doesn't look like an email address"
    And I should not be signed in

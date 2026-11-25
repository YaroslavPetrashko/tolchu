@javascript
Feature: Recover the countdown without reloading the feed
  As a fan keeping a clip open
  I want betting to close reliably and recover from a lost connection
  So that an incorrect device clock or a background tab cannot leave a stale bet pad

  Background:
    Given a creator "CountdownLab" exists
    And "CountdownLab" posted a playable clip "Will the countdown recover?" with outcomes "Yes" and "No" that freezes at 1.0 second
    And I am signed in as "countdownfan"

  Scenario: A card already expired when it connects refreshes only once
    When I watch "Will the countdown recover?" with slow card refresh replies
    And "Will the countdown recover?" expires before its countdown connects
    Then the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 1 time
    And the page should not have reloaded

  Scenario: The first failed refresh recovers automatically
    When I watch "Will the countdown recover?" with its first card refresh failing
    And "Will the countdown recover?" expires before its countdown connects
    Then the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 2 times
    And the page should not have reloaded

  Scenario: Repeated failures stop and offer a usable retry
    When I watch "Will the countdown recover?" while card refreshes are unavailable
    And "Will the countdown recover?" expires before its countdown connects
    Then "Will the countdown recover?" should offer a countdown retry after 3 attempts
    And the countdown should stop requesting the card
    When card refreshes become available and I retry "Will the countdown recover?"
    Then the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 4 times

  Scenario Outline: Device wall time cannot close betting early or late
    Given "Will the countdown recover?" locks in 6 seconds
    When I watch "Will the countdown recover?" with my device clock offset by <minutes> minutes
    Then the countdown for "Will the countdown recover?" should still allow betting
    And the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 1 time

    Examples:
      | minutes |
      | 5       |
      | -5      |

  Scenario: Returning from a background tab checks the server deadline
    When I watch the countdown for "Will the countdown recover?"
    And I background the countdown tab
    And "Will the countdown recover?" expires on the server while I am away
    And I resume the countdown tab
    Then the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 1 time
    And the page should not have reloaded

  Scenario: Returning to a Turbo cached card checks the server deadline
    When I watch the countdown for "Will the countdown recover?"
    And I leave the feed through Turbo navigation
    And "Will the countdown recover?" expires on the server while I am away
    And I return to the cached feed
    Then the recovered countdown for "Will the countdown recover?" should show the locked card
    And the countdown should have requested the card 1 time
    And the page should not have reloaded

  Scenario: Keyboard activation cannot submit the locked live form
    When I watch "Will the countdown recover?" while card refreshes are unavailable
    And I select "Yes" on "Will the countdown recover?" before countdown closure
    And "Will the countdown recover?" expires before its countdown connects
    Then "Will the countdown recover?" should offer a countdown retry after 3 attempts
    And every live betting control on "Will the countdown recover?" should be disabled
    When I try Enter and Space on "Will the countdown recover?" after countdown closure
    Then the countdown page should not have submitted a bet

  Scenario: Removing a card cancels its scheduled refresh
    When I watch the countdown for "Will the countdown recover?"
    And "Will the countdown recover?" expires before its countdown connects
    And I remove "Will the countdown recover?" before its scheduled refresh
    Then the countdown should not request the removed card

  Scenario: Removing a card aborts its in-flight refresh
    When I watch "Will the countdown recover?" with a stalled card refresh
    And "Will the countdown recover?" expires before its countdown connects
    And I remove "Will the countdown recover?" during its card refresh
    Then the removed card refresh should be aborted without retrying

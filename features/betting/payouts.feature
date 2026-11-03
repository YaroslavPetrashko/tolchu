Feature: Parimutuel payouts
  As a bettor
  I want the winners to split one shared pool, minus a flat 5% fee
  So that I know the house never profits from my losses

  Background:
    Given a creator "HoopsDaily" exists
    And "HoopsDaily" posted "Will the free throw go in?" with outcomes "Swish" and "Brick"

  Scenario: Winners split the pool in proportion to their stakes
    Given these predictions on "Will the free throw go in?":
      | user  | outcome | stake |
      | alice | Swish   | 100   |
      | bob   | Swish   | 50    |
      | carol | Brick   | 50    |
    When "Will the free throw go in?" is settled as "Swish"
    Then the bettors should end up with:
      | user  | payout | balance |
      | alice | 126    | 1,026   |
      | bob   | 63     | 1,013   |
      | carol | 0      | 950     |
    And the house should keep 9 credits
    And "HoopsDaily" should earn a creator reward of 2 credits

  Scenario: The fee is capped so winners never lose money
    Given these predictions on "Will the free throw go in?":
      | user  | outcome | stake |
      | alice | Swish   | 100   |
      | bob   | Brick   | 2     |
    When "Will the free throw go in?" is settled as "Swish"
    Then the bettors should end up with:
      | user  | payout | balance |
      | alice | 100    | 1,000   |
      | bob   | 0      | 998     |
    And the house should keep 2 credits

  Scenario: Nobody picked the winner, so everyone gets their stake back
    Given these predictions on "Will the free throw go in?":
      | user  | outcome | stake |
      | alice | Swish   | 100   |
      | bob   | Swish   | 50    |
    When "Will the free throw go in?" is settled as "Brick"
    Then the bettors should end up with:
      | user  | payout | balance |
      | alice | 100    | 1,000   |
      | bob   | 50     | 1,000   |
    And the house should keep 0 credits
    And "HoopsDaily" should earn a creator reward of 0 credits

  Scenario Outline: Creators earn more when the crowd is split
    Given "alice" has predicted "Swish" with <swish> credits on "Will the free throw go in?"
    And "bob" has predicted "Brick" with <brick> credits on "Will the free throw go in?"
    When "Will the free throw go in?" is settled as "Swish"
    Then "HoopsDaily" should earn a creator reward of <reward> credits
    And the house should keep <house> credits

    Examples:
      | swish | brick | reward | house |
      | 100   | 100   | 5      | 5     |
      | 100   | 60    | 3      | 5     |
      | 100   | 20    | 1      | 5     |

  Scenario: Seeing my winnings on the clip
    Given I am signed in as "alice"
    And I have predicted "Swish" with 100 credits on "Will the free throw go in?"
    And "carol" has predicted "Brick" with 100 credits on "Will the free throw go in?"
    When "Will the free throw go in?" is settled as "Swish"
    And I go to the feed
    Then the market "Will the free throw go in?" should say "You called it! Swish paid 190 credits (+90)."
    And my balance should be 1,090 credits

  Scenario: Seeing a losing prediction on the clip
    Given I am signed in as "carol"
    And I have predicted "Brick" with 100 credits on "Will the free throw go in?"
    And "alice" has predicted "Swish" with 100 credits on "Will the free throw go in?"
    When "Will the free throw go in?" is settled as "Swish"
    And I go to the feed
    Then the market "Will the free throw go in?" should say "You picked Brick and lost 100 credits."

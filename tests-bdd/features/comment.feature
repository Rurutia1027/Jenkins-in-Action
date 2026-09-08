Feature: Comment on a bug
  Comments belong to a bug and are counted against it.

  Background:
    Given a bug exists:
      | title       | BDD Comment Bug        |
      | description | Needs two comments     |
      | priority    | Low                    |
      | status      | Open                   |

  Scenario: Two comments are attached to a bug
    When comments are added:
      | author        | content              |
      | Ada Lovelace  | Reproduced on iOS    |
      | Grace Hopper  | Also fails on Android |
    Then the bug has 2 comments
    And a comment by "Ada Lovelace" says "Reproduced on iOS"
    And a comment by "Grace Hopper" says "Also fails on Android"

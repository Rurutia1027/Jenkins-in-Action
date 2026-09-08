Feature: Delete a bug
  A deleted bug is no longer available.

  Background:
    Given a bug exists:
      | title       | BDD Delete Bug              |
      | description | Bug used for the delete rule |
      | priority    | High                        |
      | status      | Open                        |

  Scenario: The bug is removed
    When the bug is deleted
    Then the bug "BDD Delete Bug" does not exist

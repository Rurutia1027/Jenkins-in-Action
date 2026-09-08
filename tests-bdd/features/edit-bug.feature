Feature: Edit a bug
  Status and priority changes are persisted on the same bug.

  Background:
    Given a bug exists:
      | title       | BDD Edit Bug          |
      | description | Needs a status change |
      | priority    | Medium                |
      | status      | Open                  |

  Scenario: A bug moves to In Progress at High priority
    When the bug is updated to:
      | title       | BDD Edit Bug |
      | description | Being worked |
      | status      | In Progress  |
      | priority    | High         |
    Then the bug "BDD Edit Bug" exists
    And its status is "In Progress"
    And its priority is "High"
    And its description is "Being worked"

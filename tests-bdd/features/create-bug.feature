Feature: Create a bug
  A recorded defect is stored with the reporter's priority
  and starts life as Open.

  Scenario: A reporter files a Medium bug
    Given the API is healthy
    When a bug is recorded with:
      | title       | BDD Login button broken |
      | description | Sign in does nothing    |
      | priority    | Medium                  |
    Then the bug "BDD Login button broken" exists
    And its status is "Open"
    And its priority is "Medium"

  Scenario: A bug cannot be recorded without a title
    When a bug is recorded with:
      | title       |                         |
      | description | missing title           |
      | priority    | Low                     |
    Then the recording is rejected

#!/bin/bash

# Checks that the year has been closed correctly in the ledger, i.e. that
# the result booked on account 8999 is the same as the result in the result
# report, and that the balance report balances. Uses the same selections of
# the ledger as the reports do.
#
#   - The year is closed, but with another amount than the result: error.
#   - The balance report doesn't balance: error.
#   - The year hasn't been closed yet: a warning only, so that reports can
#     be made during the year.
#
# Note! This makes the assumption that all currencies are in the same currency
function check_year_end() {
  local ledger_file="$1"
  local start_of_period="$2"
  local end_of_period="$3"
  local result_accounts balance_accounts messages

  result_accounts=$(bean-query -f csv "$ledger_file" "SELECT account, sum(number) AS amount WHERE account ~ '^(Income|Expenses)' ORDER BY account" | yq -pc -oj '.')
  balance_accounts=$(bean-query -f csv "$ledger_file" "SELECT account, sum(number) AS amount WHERE date >= $start_of_period AND date <= $end_of_period AND account ~ '^(Assets|Liabilities)' ORDER BY account" | yq -pc -oj '.')

  messages=$(jq -rn --argjson result_accounts "$result_accounts" --argjson balance_accounts "$balance_accounts" '
    def total: map(.amount | tonumber) | add // 0;
    def cents: . * 100 | round;
    def money: cents as $c
      | (if $c < 0 then "-" else "" end)
        + (($c | fabs) / 100 | floor | tostring) + "."
        + (($c | fabs) % 100 | tostring | if length < 2 then "0" + . else . end);

    ($result_accounts | map(select(.account | test("^Income:8999")))) as $closing
    | ($closing | length > 0) as $closed
    | ($closing | total) as $booked
    | ($result_accounts - $closing | total * -1) as $result
    | ($balance_accounts | total) as $balance
    # What the balance report is off by, apart from a result that is not booked
    | ($balance - ($result - $booked)) as $unexplained

    | (if $closed and ($booked | cents) != ($result | cents) then
        "Error: the result booked on account 8999 (\($booked | money)) is not the result according to the result report (\($result | money)). The difference is \($booked - $result | money)."
      elif ($closed | not) and ($result | cents) != 0 then
        "Warning: the year has not been closed - nothing is booked on account 8999. The result so far is \($result | money), and the balance report will be off by that amount."
      else empty end),
      (if ($unexplained | cents) != 0 then
        "Error: the balance report does not balance - it is off by \($unexplained | money), apart from the result. Is something booked on an account that is not in the reports (e.g. Equity:Opening-Balances), or dated outside of the period?"
      else empty end)')

  if [ -n "$messages" ]; then
    echo "$messages" >&2
  fi
  if echo "$messages" | grep -q '^Error:'; then
    return 1
  fi
}

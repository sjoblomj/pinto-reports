#!/bin/bash

# Checks that the year has been closed correctly in the ledger, i.e. that
# the result booked on account 8999 is the same as the result in the result
# report, and that the balance report balances. Uses the same selections of
# the ledger as the reports do. Expects transactions.sh to be sourced.
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
  local result_accounts balance_accounts closing messages earlier opening

  # An opening balance transaction would be counted on top of the balances from the earlier years
  earlier=$(query_ledger "$ledger_file" "SELECT count(*) AS postings WHERE date < $start_of_period" | jq 'map(.postings) | add // 0')
  opening=$(query_ledger "$ledger_file" "SELECT count(*) AS postings WHERE date = $start_of_period AND description = 'Opening balance'" | jq 'map(.postings) | add // 0')
  if [ "$earlier" -gt 0 ] && [ "$opening" -gt 0 ]; then
    echo "Error: $ledger_file has both transactions before $start_of_period and an \"Opening balance\" transaction on that date. The opening balance is the sum of those, so remove one of them." >&2
    return 1
  fi


  # Everything up until the end of the period, so that the checks also work for a part of a year
  result_accounts=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE date <= $end_of_period AND account ~ '^(Income|Expenses)' ORDER BY account")
  balance_accounts=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE date <= $end_of_period AND account ~ '^(Assets|Liabilities)' ORDER BY account")
  closing=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $(period_condition "$start_of_period" "$end_of_period") AND account ~ '^Income:8999' ORDER BY account")

  messages=$(jq -rn --argjson result_accounts "$result_accounts" --argjson balance_accounts "$balance_accounts" --argjson closing "$closing" '
    def total: map(.amount | tonumber) | add // 0;
    def cents: . * 100 | round;
    def money: cents as $c
      | (if $c < 0 then "-" else "" end)
        + (($c | fabs) / 100 | floor | tostring) + "."
        + (($c | fabs) % 100 | tostring | if length < 2 then "0" + . else . end);

    ($closing | length > 0) as $closed
    | ($closing | total) as $booked
    # The result that is not booked on 8999. Zero when the year is closed correctly.
    | ($result_accounts | total * -1) as $unbooked
    | ($balance_accounts | total) as $balance

    | (if $closed and ($unbooked | cents) != 0 then
        "Error: the result booked on account 8999 in the period is \($booked | money), but it should be \($booked + $unbooked | money) according to the income and expenses. The difference is \($unbooked * -1 | money)."
      elif ($closed | not) and ($unbooked | cents) != 0 then
        "Warning: the year has not been closed - nothing is booked on account 8999 in the period. The result that is not booked is \($unbooked | money), and the balance report will be off by that amount."
      else empty end),
      (if ($balance - $unbooked | cents) != 0 then
        "Error: the balance report does not balance - it is off by \($balance - $unbooked | money), apart from the result. Is something booked on an account that is not in the reports (e.g. Equity:Opening-Balances)?"
      else empty end)')

  if [ -n "$messages" ]; then
    echo "$messages" >&2
  fi
  if echo "$messages" | grep -q '^Error:'; then
    return 1
  fi
}

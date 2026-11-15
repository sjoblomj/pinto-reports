#!/bin/bash

# The opening balance of the period is everything that is dated before the
# start of the period, together with the transactions tagged #opening-balance
# on the first day of the period, if there are any. All other transactions
# from the start to the end of the period are the transactions of the period.
#
# These functions print the conditions to use in bean-query for the two.
function opening_transaction_condition() {
  local start_of_period="$1"
  echo "(date = $start_of_period AND 'opening-balance' IN tags)"
}

function opening_condition() {
  local start_of_period="$1"
  echo "(date < $start_of_period OR $(opening_transaction_condition "$start_of_period"))"
}

function period_condition() {
  local start_of_period="$1"
  local end_of_period="$2"
  echo "(date >= $start_of_period AND date <= $end_of_period AND NOT $(opening_transaction_condition "$start_of_period"))"
}

# Runs the given query on the ledger, and prints the result as JSON
function query_ledger() {
  local ledger_file="$1"
  local query="$2"
  bean-query -f csv "$ledger_file" "$query" | yq -pc -oj '.'
}

# Prints the opening balances of the asset and liability accounts as a JSON
# array of objects with "account" and "amount".
function get_opening_balances() {
  local ledger_file="$1"
  local start_of_period="$2"
  query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $(opening_condition "$start_of_period") AND account ~ '^(Assets|Liabilities)' ORDER BY account" |
    jq 'map(.amount = (.amount | tonumber))'
}

# Prints all postings of the period as a JSON array, with a verification
# number ("vernr") and a running transaction number ("seq") added to each.
#
# The verification number is taken from the "id" metadata of the transaction:
# it is the first part of the id that is a number, when the id is split on
# underscores (e.g. "nordea_16_2025-01-31_1038" -> 16). That way the numbers
# in the reports are the same as the numbers used when the verifications
# were filed.
#
# Transactions without an id get:
#   - the numbers following the highest id, if they come after the last
#     transaction that has an id (e.g. the transaction closing the year);
#   - 0 otherwise (e.g. the opening of the year).
function get_transaction_list() {
  local ledger_file="$1"
  local start_of_period="$2"
  local end_of_period="$3"
  query_ledger "$ledger_file" "SELECT date, id as transaction_id, entry_meta('id') as id, description, account, number as amount WHERE $(period_condition "$start_of_period" "$end_of_period")" |
    jq '
      def id_number:
        (.id // "" | tostring | split("_") | map(select(test("^[0-9]+$"))) | first) as $n
        | if $n == null then null else ($n | tonumber) end;

      map(.amount = (.amount | tonumber) | .id_number = id_number)
      | reduce .[] as $i ({seq: {}, arr: []};
          .seq[$i.transaction_id] //= (.seq | length)
          | .arr += [$i + {seq: .seq[$i.transaction_id]}]
        ) | .arr
      | (map(.id_number // empty) | max) as $highest
      | (map(select(.id_number != null) | .seq) | max // -1) as $last_with_id
      | (map(select(.id_number == null and .seq > $last_with_id) | .seq) | unique) as $trailing
      | map(.seq as $seq
          | .vernr = (
              if .id_number != null then .id_number
              elif $seq > $last_with_id then ($highest // 0) + 1 + ($trailing | index($seq))
              else 0 end)
          | del(.id_number))'
}

#!/bin/bash

# Prints all postings of the ledger as a JSON array, with a verification
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
#   - 0 otherwise (e.g. the opening balance and the opening of the year).
#
# Note! This makes the assumption that all currencies are in the same currency
function get_transaction_list() {
  local ledger_file="$1"
  bean-query "$ledger_file" -f csv "SELECT date, id as transaction_id, entry_meta('id') as id, description, account, number as amount" |
    yq -pc -oj '.' |
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
              elif $seq > $last_with_id then ($highest // -1) + 1 + ($trailing | index($seq))
              else 0 end)
          | del(.id_number))'
}

#!/bin/bash

# Note! This makes the assumption that all currencies are in the same currency
function get_transaction_list() {
  local ledger_file="$1"
  bean-query "$ledger_file" -f csv "SELECT date, id as transaction_id, entry_meta('id') as id, description, account, number as amount" |
    yq -pc -oj '.' |
    jq 'reduce .[] as $i ({};
        .vernr |= (.[$i.transaction_id] //= length) | .arr += [$i + {vernr: .vernr[$i.transaction_id]}]
      ) | .arr
      | map(.amount = (.amount | tonumber))'
}

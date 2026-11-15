#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/typst.sh
source "$SCRIPT_DIR"/transactions.sh

report_type="Huvudbok"
config_file="$1"
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
start_of_period=$(     jq -r    '.["start-of-period"]' "$config_file")
end_of_period=$(       jq -r      '.["end-of-period"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")
report_type=$(         jq -r      ".[\"report-type\"] // \"$report_type\"" "$config_file")

opening_file=$(mktemp)
trap 'rm -f "$opening_file"' EXIT

get_opening_balances "$ledger_file" "$start_of_period" |
  map_account_names "$account_mappings_src" > "$opening_file"

# Each account gets its opening balance as the first transaction, followed by the transactions of the period.
# Accounts with neither an opening balance nor any transactions are left out.
get_transaction_list "$ledger_file" "$start_of_period" "$end_of_period" |
  map_account_names "$account_mappings_src" |
  jq --arg opening_balance_account "$OPENING_BALANCE_ACCOUNT" '[.[] | select(.account != $opening_balance_account)]' |
  jq --arg startdate "$start_of_period" --slurpfile opening "$opening_file" '
    ($opening[0] | map(select(.amount != 0))) as $opening
    | group_by(.account) as $period
    | ($opening + ($period | map(.[0])) | map({account, account_internal}) | unique_by(.account)) as $accounts
    | $accounts | map(.account as $account | . + {
        "transactions": (
          [{"date": $startdate, "description": "Opening balance", "vernr": 0, "amount": (($opening | map(select(.account == $account)) | first | .amount) // 0)}]
          + ($period | map(select(.[0].account == $account)) | first // [] | map(del(.account, .account_internal, .seq))))
      })' > "$report_output_file.json"

# Create Typst report
print_typst_report "$report_type" "account-table" "$report_output_file.json"

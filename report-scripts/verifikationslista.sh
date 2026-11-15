#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/typst.sh
source "$SCRIPT_DIR"/transactions.sh

report_type="Verifikationslista"
config_file="$1"
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
start_of_period=$(     jq -r    '.["start-of-period"]' "$config_file")
end_of_period=$(       jq -r      '.["end-of-period"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")
report_type=$(         jq -r      ".[\"report-type\"] // \"$report_type\"" "$config_file")

jsonfile=$(mktemp)
trap 'rm -f "$jsonfile"' EXIT

get_transaction_list "$ledger_file" "$start_of_period" "$end_of_period" |
  map_account_names "$account_mappings_src" > "$jsonfile"

# Each transaction is a verification of its own, even when several share a number
jq 'group_by([.vernr, .seq])' "$jsonfile" |
    jq 'map(first as $f | {"date": $f.date, "transaction_id": $f.transaction_id, "id": $f.id, "description": $f.description, "vernr": $f.vernr, "transactions": (map({"account": .account, "amount": .amount}))})' > "$report_output_file.json"

# Create Typst report
print_typst_report "$report_type" "verification-table" "$report_output_file.json"

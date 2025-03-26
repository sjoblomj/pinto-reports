#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/transactions.sh

report_type="Huvudbok"
config_file="$1"
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
start_of_period=$(     jq -r    '.["start-of-period"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")
report_type=$(         jq -r      ".[\"report-type\"] // \"$report_type\"" "$config_file")

get_transaction_list "$ledger_file" |
  map_account_names "$account_mappings_src" |
  jq '[.[] | select(.account != "Equity:Opening-Balances")]' |
  jq 'group_by(.account)' |
  jq --arg startdate "$start_of_period" 'map([.[0] as $fst | select($fst.description == "Opening balance")[0] // {"date": $startdate, "id": "nordea_-1", "description": "Opening balance", "account": $fst.account, "account_internal": $fst.account_internal, "vernr": 0, "amount": 0.00}] + [.[] | select(.description != "Opening balance")])' |
  jq 'map({"account": (. | first | .account), "account_internal": (. | first | .account_internal), "transactions": (map(del(.account, .account_internal)))})' > "$report_output_file.json"

# Turn to latex commands
echo "\\reporttype{$report_type}"
echo "\\begin{accounttable}"
jq -r 'map("\n    \\accountheaderrow{" + .account + "}\n    \\accountopeningrow{" + (.transactions | first | .amount | tostring) + "}\n" + (.transactions[1:] | map("    \\accounttransaction{" + (.vernr | tostring) + "}{" + .date + "}{" + .description + "}{" + (.amount | tostring) + "}") | flatten | join("\n")) + "\n    \\accountclosingrow{}") | flatten | .[]' "$report_output_file.json"
echo "\\end{accounttable}"

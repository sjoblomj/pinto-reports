#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/transactions.sh

report_type="Verifikationslista"
config_file="$1"
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")
report_type=$(         jq -r      ".[\"report-type\"] // \"$report_type\"" "$config_file")

jsonfile=$(mktemp)

get_transaction_list "$ledger_file" |
  map_account_names "$account_mappings_src" > "$jsonfile"

jq '[.[] | select(.vernr != 0 and .description != "Opening balance")]' "$jsonfile" | \
    jq 'group_by(.vernr)' |
    jq 'map(first as $f | {"date": $f.date, "transaction_id": $f.transaction_id, "id": $f.id, "description": $f.description, "vernr": $f.vernr, "transactions": (map({"account": .account, "amount": .amount}))})' > "$report_output_file.json"

# Turn to latex commands
echo "\\reporttype{$report_type}"
echo "\\begin{verificationtable}"
jq -r '. | map("    \\verificationitem{" + (.vernr | tostring) + "}{" + .date + "}{" + .description + "}\n" + (.transactions | [(.[0:-1] | map("      \\transactionitem*{" + .account + "}{" + (.amount | tostring) + "}")), (.[-1] | "      \\transactionitem{" + .account + "}{" + (.amount | tostring) + "}")] | flatten | join("\n")) + "\n") | .[]' "$report_output_file.json"
echo "\\end{verificationtable}"

rm -f "$jsonfile"

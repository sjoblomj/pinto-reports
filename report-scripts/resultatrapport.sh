#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/sheets.sh

config_file="$1"
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
report_type=$(         jq -r        '.["report-type"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")

headers_file=$(mktemp)
notes_file=$(  mktemp)

jq -r '.["report-headers"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" > "$headers_file"
jq -c          '.["notes"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" | parse_notes "$account_mappings_src" > "$notes_file"

bean-query -f csv "$ledger_file" 'SELECT account, sum(number) AS amount WHERE account !~ "^(Equity|Assets|Liabilities)" ORDER BY account' |
  yq -pc -oj '.' |
  jq 'map(.amount = (.amount * -1))' |
  create_json_sheet "$account_mappings_src" "$headers_file" "$notes_file" > "$report_output_file.json"

# Create Latex report
echo "\\reporttype{$report_type}"
echo "\\begin{resulttable}"
jq -r 'map("\n  \\resultheaderrow{" + .category + "}\n" + (.accounts | map("  \\resultitem{" + .account + "}{" + .note + "}{" + (.amount | tostring) + "}") | join("\n")) + "\n  \\resultresult{}") | join("\n")' "$report_output_file.json"
echo "\\end{resulttable}"

# Clean up files
rm -f "$headers_file" "$notes_file"

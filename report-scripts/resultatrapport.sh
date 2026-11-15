#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/typst.sh
source "$SCRIPT_DIR"/sheets.sh
source "$SCRIPT_DIR"/transactions.sh

config_file="$1"
start_of_period=$(     jq -r    '.["start-of-period"]' "$config_file")
end_of_period=$(       jq -r      '.["end-of-period"]' "$config_file")
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
report_type=$(         jq -r        '.["report-type"]' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")

headers_file=$(mktemp)
notes_file=$(  mktemp)
trap 'rm -f "$headers_file" "$notes_file"' EXIT

jq -r '.["report-headers"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" > "$headers_file"
jq -c          '.["notes"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" | parse_notes "$account_mappings_src" > "$notes_file"

query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $(period_condition "$start_of_period" "$end_of_period") AND account !~ '(Equity|Assets|Liabilities)' AND account !~ '^Income:8999' ORDER BY account" |
  jq 'map(.amount = (.amount * -1))' |
  create_json_sheet "$account_mappings_src" "$headers_file" "$notes_file" > "$report_output_file.json"

# Create Typst report
print_typst_report "$report_type" "result-table" "$report_output_file.json"

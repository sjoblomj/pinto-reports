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

start_of_period_file=$(mktemp)
end_of_period_file=$(  mktemp)
report_file=$(         mktemp)
headers_file=$(        mktemp)
notes_file=$(          mktemp)
trap 'rm -f "$start_of_period_file" "$end_of_period_file" "$report_file" "$headers_file" "$notes_file"' EXIT

jq -r '.["report-headers"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" > "$headers_file"
jq -c          '.["notes"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" | parse_notes "$account_mappings_src" > "$notes_file"

for startend in start end; do
  # Get ledger from start or end of period
  output_file="${startend}_of_period_file"
  if [ "$startend" = "start" ]; then
    condition=$(opening_condition "$start_of_period")
  else
    # The closing balance is everything up until the end of the period
    condition="date <= $end_of_period"
  fi
  query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $condition AND account ~ '^(Assets|Liabilities)' ORDER BY account" | jq "map(. + {\"${startend}_amount\": .amount} | del(.amount))" > "${!output_file}"
done

# Combine to one array
jq -s '.[0] + .[1]' "$start_of_period_file" "$end_of_period_file" > "$report_file"

# Group accounts together; explicitly set .start_amount and .end_amount if missing; filter away where both .start_amount and .end_amount == 0; calculate diff
jq '[group_by(.account)[] | add]' "$report_file" |
  jq 'map(. + {"start_amount": (if .start_amount == null then 0 else .start_amount end), "end_amount": (if .end_amount == null then 0 else .end_amount end)})
  | [.[] | select(.start_amount != 0 or .end_amount != 0)]
  | map(. + {"diff": (((.end_amount - .start_amount) * 100 | round) / 100)})' |
  create_json_sheet "$account_mappings_src" "$headers_file" "$notes_file" > "$report_output_file.json"

# Create Typst report
print_typst_report "$report_type" "balance-table" "$report_output_file.json"

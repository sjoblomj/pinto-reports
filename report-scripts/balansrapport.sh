#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/sheets.sh

config_file="$1"
start_of_period=$(      jq -r       '.["start-of-period"]' "$config_file")
end_of_period=$(        jq -r         '.["end-of-period"]' "$config_file")
ledger_file=$(          jq -r                '.["ledger"]' "$config_file")
account_mappings_src=$( jq -r      '.["account-mappings"]' "$config_file")
report_type=$(          jq -r           '.["report-type"]' "$config_file")
report_output_file=$(   jq -r    '.["report-output-file"]' "$config_file")
period_result_account=$(jq -r '.["period-result-account"]' "$config_file" | get_account_name "$account_mappings_src")

start_of_period_file=$(mktemp)
end_of_period_file=$(  mktemp)
equity_at_start_file=$(mktemp)
equity_at_end_file=$(  mktemp)
report_file=$(         mktemp)
headers_file=$(        mktemp)
notes_file=$(          mktemp)

jq -r '.["report-headers"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" > "$headers_file"
jq -c          '.["notes"] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" | parse_notes "$account_mappings_src" > "$notes_file"

for startend in start end; do
  # Get ledger from start or end of period
  output_file="${startend}_of_period_file"
  if [ "$startend" = "start" ]; then
    # Both start and end should be the same date
    startdate="$start_of_period"
    enddate="$start_of_period"
  else
    startdate="$start_of_period"
    enddate="$end_of_period"
  fi
  bean-query -f csv "$ledger_file" "SELECT account, sum(number) AS amount WHERE date >= $startdate AND date <= $enddate AND account ~ '^(Assets|Liabilities)' ORDER BY account" | yq -pc -oj "map(. + {\"${startend}_amount\": .amount} | del(.amount))" > "${!output_file}"

  # Get start/end equity from config
  f="equity_at_${startend}_file"
  jq -c --arg startend "$startend" '.["equity-at-" + $startend + "-of-period"] | map(to_entries) | flatten | map(. + {($startend + "_amount"): .value, "accountnumber": .key} | del(.key, .value))' "$config_file" | map_account_name "$account_mappings_src" | jq 'map(del(.accountnumber))' > "${!f}"
done

# Combine to one array
jq -s '.[0] + .[1] + .[2] + .[3]' "$start_of_period_file" "$end_of_period_file" "$equity_at_start_file" "$equity_at_end_file" > "$report_file"

# Force-insert the period-result-account (by summing all .end_amounts); explicitly set .start_amount and .end_amount if missing; filter away where both .start_amount and .end_amount == 0; calculate diff
jq --arg period_result_account "$period_result_account" '[. + [{"account": $period_result_account, "end_amount": ((([.[].end_amount] | add) * (-100) | round) / 100)}] | group_by(.account)[] | add]' "$report_file" |
  jq 'map(. + {"start_amount": (if .start_amount == null then 0 else .start_amount end), "end_amount": (if .end_amount == null then 0 else .end_amount end)})
  | [.[] | select(.start_amount != 0 or .end_amount != 0)]
  | map(. + {"diff": (((.end_amount - .start_amount) * 100 | round) / 100)})' |
  create_json_sheet "$account_mappings_src" "$headers_file" "$notes_file" > "$report_output_file.json"

# Create Latex report
echo "\\reporttype{$report_type}"
echo "\\begin{balancetable}"
jq -r 'map("\n  \\balanceheaderrow{" + .category + "}\n" + (.accounts | map("  \\balanceitem{" + .account + "}{" + .note + "}{" + (.start_amount | tostring) + "}{" + (.diff | tostring) + "}{" + (.end_amount | tostring) + "}") | join("\n")) + "\n  \\balanceresult{}") | join("\n")' "$report_output_file.json"
echo "\\end{balancetable}"

# Clean up files
rm -f "$start_of_period_file" "$end_of_period_file" "$equity_at_start_file" "$equity_at_end_file" "$report_file" "$headers_file" "$notes_file"

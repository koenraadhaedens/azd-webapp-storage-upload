 Plan SKU quota to check.#!/usr/bin/env bash
# Examples: S1, P1v3, B1, F1, D1 (these appear as "<SKU> VMs" in localizedValue)
SKU="${SKU:-S1}"

# Quota API version (current GA per Learn examples)
API_VERSION="${API_VERSION:-2025-09-01}"

SUB_ID="$(az account show --query id -o tsv)"

# Regions list
mapfile -t REGIONS < <(az account list-locations --query "[].name" -o tsv | sort)

echo "Subscription: $SUB_ID"
echo "Checking App Service quota via Microsoft.Quota for SKU: $SKU"
echo "Endpoint pattern: Microsoft.Web/locations/<region>/providers/Microsoft.Quota/quotas" 
echo

printf "%-18s %-8s %-8s %s\n" "Region" "Used" "Limit" "QuotaName"
printf "%-18s %-8s %-8s %s\n" "------" "----" "-----" "---------"

for r in "${REGIONS[@]}"; do
  # Query quota list for this region
  json="$(az rest --method get \
    --url "https://management.azure.com/subscriptions/${SUB_ID}/providers/Microsoft.Web/locations/${r}/providers/Microsoft.Quota/quotas?api-version=${API_VERSION}" \
    -o json 2>/dev/null || true)"

  [[ -z "$json" ]] && continue

  # Find the record for the SKU by name == SKU (e.g. "S1") OR localizedValue contains "S1 VMs"
  # Some responses might not include current usage (used); when missing we show "?"
  line="$(jq -r --arg sku "$SKU" '
    .value[]? |
    select(.name == $sku or ((.properties.name.localizedValue // "") | contains($sku + " VMs"))) |
    [
      (.properties.currentValue // .properties.usages?.value // null),
      (.properties.limit.value // .properties.limit // null),
      (.properties.name.localizedValue // .name)
    ] | @tsv
  ' <<< "$json" | head -n 1)"

  [[ -z "$line" ]] && continue

  used="$(cut -f1 <<< "$line")"
  limit="$(cut -f2 <<< "$line")"
  qname="$(cut -f3 <<< "$line")"

  # Normalize missing fields
  [[ "$used" == "null" || -z "$used" ]] && used="?"
  [[ "$limit" == "null" || -z "$limit" ]] && continue

  # Show only regions where quota exists (>0)
  if [[ "$limit" =~ ^-?[0-9]+$ ]] && (( limit > 0 )); then
    printf "%-18s %-8s %-8s %s\n" "$r" "$used" "$limit" "$qname"
  fi
done

echo
echo "Tip:"
echo "  - To check another SKU:     SKU=P1v3 ./appservice-available-regions.sh"
echo "  - To check free tier:       SKU=F1   ./appservice-available-regions.sh"



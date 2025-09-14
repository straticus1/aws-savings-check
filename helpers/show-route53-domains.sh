#!/bin/bash

# Route53 Domain Overview
# Shows all domains and their nameservers

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AWS Route53 Domain Overview ===${NC}"
echo -e "${BLUE}Time: $(date)${NC}"
echo ""

# Check AWS CLI configuration
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    exit 1
fi

# Get all hosted zones
echo -e "${YELLOW}Fetching Route53 Hosted Zones...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

zones=$(aws route53 list-hosted-zones \
    --query 'HostedZones[*].[Id,Name,Config.PrivateZone]' \
    --output text)

if [ -n "$zones" ]; then
    total_zones=0
    public_zones=0
    private_zones=0

    while IFS=$'\t' read -r zone_id zone_name is_private; do
        ((total_zones++))
        
        # Remove trailing dot from domain name
        zone_name=${zone_name%?}
        
        # Get name servers for this zone
        nameservers=$(aws route53 get-hosted-zone \
            --id "${zone_id##*/}" \
            --query 'DelegationSet.NameServers' \
            --output text)
        
        if [ "$is_private" == "true" ]; then
            echo -e "${CYAN}Domain:${NC} $zone_name ${YELLOW}(Private)${NC}"
            ((private_zones++))
        else
            echo -e "${CYAN}Domain:${NC} $zone_name ${GREEN}(Public)${NC}"
            ((public_zones++))
        fi
        
        echo -e "${CYAN}Zone ID:${NC} ${zone_id##*/}"
        echo -e "${CYAN}Nameservers:${NC}"
        
        # Display nameservers in a clean format
        if [ -n "$nameservers" ]; then
            echo "$nameservers" | tr '\t' '\n' | while read -r ns; do
                echo -e "  ${GREEN}•${NC} $ns"
            done
        else
            echo -e "  ${RED}No nameservers found${NC}"
        fi
        
        echo "────────────────────────────────────────────────────────────────────"
    done <<< "$zones"
    
    # Print summary
    echo -e "\n${BLUE}Summary:${NC}"
    echo -e "Total Hosted Zones:    $total_zones"
    echo -e "Public Zones:          $public_zones"
    echo -e "Private Zones:         $private_zones"
else
    echo -e "${YELLOW}No hosted zones found in Route53${NC}"
fi

# Check for registered domains through Route53 Domains service
echo -e "\n${YELLOW}Checking Route53 Domain Registrations...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

domains=$(aws route53domains list-domains \
    --query 'Domains[*].[DomainName,ExpirationDate]' \
    --output text 2>/dev/null)

if [ -n "$domains" ]; then
    echo -e "${CYAN}Registered Domains:${NC}"
    while IFS=$'\t' read -r domain_name expiry_date; do
        echo -e "${GREEN}•${NC} $domain_name"
        echo -e "  ${CYAN}Expires:${NC} $expiry_date"
        
        # Get domain nameservers
        ns_info=$(aws route53domains get-domain-detail \
            --domain-name "$domain_name" \
            --query 'Nameservers[*].[Name]' \
            --output text 2>/dev/null)
        
        if [ -n "$ns_info" ]; then
            echo -e "  ${CYAN}Nameservers:${NC}"
            echo "$ns_info" | tr '\t' '\n' | while read -r ns; do
                echo -e "    ${GREEN}•${NC} $ns"
            done
        fi
        echo "────────────────────────────────────────────────────────────────────"
    done <<< "$domains"
else
    echo -e "${YELLOW}No domains registered through Route53 Domains${NC}"
fi
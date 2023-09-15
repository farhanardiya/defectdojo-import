#!/bin/sh

# Token
DEFECTDOJO_TOKEN="$1"

# Get Repo Name
git config --global --add safe.directory $(pwd)
REPO_NAME=$(basename $(git config --get remote.origin.url) | awk -F '.' '{print $1}')

# Get PR Name
PR_NAME="$2"

# Get IP Address
IP_DEFECTDOJO="$3"

# Current Date
current_date=$(date +'%Y-%m-%d')

# Get Product ID
PRODUCT_ID=$(curl -X 'GET' \
  "http://$IP_DEFECTDOJO:8080/api/v2/products/?name=$REPO_NAME" --connect-timeout 10 \
  -H 'accept: application/json' \
  -H "Authorization: Token $DEFECTDOJO_TOKEN" | jq -r '.results[0].id')

# PRODUCT_ID either "null" or a number

if [ "$PRODUCT_ID" = "null" ]; then
    # Create new product
    PRODUCT_ID=$(curl -X 'POST' \
  		"http://$IP_DEFECTDOJO:8080/api/v2/products/" --connect-timeout 10 \
  		-H 'accept: application/json' \
  		-H 'Content-Type: application/json' \
  		-H "Authorization: Token $DEFECTDOJO_TOKEN" \
  		-d '{
  		"tags": [
  		],
  		"name": "'$REPO_NAME'",
  		"description": "",
  		"prod_numeric_grade": null,
  		"business_criticality": null,
  		"platform": null,
  		"lifecycle": null,
  		"origin": null,
  		"user_records": null,
  		"revenue": null,
  		"external_audience": false,
  		"internet_accessible": false,
  		"enable_simple_risk_acceptance": false,
  		"enable_full_risk_acceptance": false,
  		"product_manager": null,
  		"technical_contact": null,
  		"team_manager": null,
  		"prod_type": 1,
  		"sla_configuration": 1,
  		"regulations": [
  		]
		}' | jq -r '.id')
	# Create new engagement
	ENGAGEMENT_ID=$(curl -X 'POST' \
  		"http://$IP_DEFECTDOJO:8080/api/v2/engagements/" --connect-timeout 10 \
  		-H 'accept: application/json' \
  		-H 'Content-Type: application/json' \
  		-H "Authorization: Token $DEFECTDOJO_TOKEN" \
  		-d '{
  		"tags": [
  		],
  		"name": "'$PR_NAME'",
  		"description": "",
  		"version": null,
  		"first_contacted": null,
  		"target_start": "'$current_date'",
  		"target_end": "'$current_date'",
  		"reason": null,
  		"tracker": null,
  		"test_strategy": null,
  		"threat_model": false,
  		"api_test": false,
  		"pen_test": false,
  		"check_list": false,
  		"status": "In Progress",
  		"engagement_type": "CI/CD",
  		"build_id": null,
  		"commit_hash": null,
  		"branch_tag": null,
  		"source_code_management_uri": null,
  		"deduplication_on_engagement": true,
  		"lead": null,
  		"requester": null,
  		"preset": null,
  		"report_type": null,
  		"product": '$PRODUCT_ID',
  		"build_server": null,
  		"source_code_management_server": null,
  		"orchestration_engine": null
		}' | jq -r '.id')
else
	# Get Engagement ID
    ENGAGEMENT_ID=$(curl -X 'GET' \
  		"http://$IP_DEFECTDOJO:8080/api/v2/engagements/?product=$PRODUCT_ID&name=$PR_NAME" --connect-timeout 10 \
  		-H 'accept: application/json' \
  		-H "Authorization: Token $DEFECTDOJO_TOKEN" | jq -r '.results[0].id')

  	# Engagement ID either "null" or a number
  	if [ "$ENGAGEMENT_ID" = "null" ]; then
  		# Create Engagement
  		ENGAGEMENT_ID=$(curl -X 'POST' \
  			"http://$IP_DEFECTDOJO:8080/api/v2/engagements/" --connect-timeout 10 \
  			-H 'accept: application/json' \
  			-H 'Content-Type: application/json' \
  			-H "Authorization: Token $DEFECTDOJO_TOKEN" \
  			-d '{
  			"tags": [
  			],
  			"name": "'$PR_NAME'",
  			"description": "",
  			"version": null,
  			"first_contacted": null,
  			"target_start": "'$current_date'",
  			"target_end": "'$current_date'",
  			"reason": null,
  			"tracker": null,
  			"test_strategy": null,
  			"threat_model": false,
  			"api_test": false,
  			"pen_test": false,
  			"check_list": false,
  			"status": "In Progress",
  			"engagement_type": "CI/CD",
  			"build_id": null,
  			"commit_hash": null,
  			"branch_tag": null,
  			"source_code_management_uri": null,
  			"deduplication_on_engagement": true,
  			"lead": null,
  			"requester": null,
  			"preset": null,
  			"report_type": null,
  			"product": '$PRODUCT_ID',
  			"build_server": null,
  			"source_code_management_server": null,
  			"orchestration_engine": null
			}' | jq -r '.id')
  	else
  		true
    fi
fi

echo $ENGAGEMENT_ID

# Gitleaks POST
curl -X "POST" \
  "http://$IP_DEFECTDOJO:8080/api/v2/import-scan/" --connect-timeout 10 \
  -H "accept: application/json" \
  -H "Authorization: Token $DEFECTDOJO_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "minimum_severity=Info" \
  -F "active=true" \
  -F "verified=true" \
  -F "scan_type=Gitleaks Scan" \
  -F "file=@gitleaks.json;type=application/json" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "close_old_findings=false" \
  -F "push_to_jira=false" \
  -F "test_title=Gitleaks Scan" \
  -F "deduplication_on_engagement=true"

# Trivy SCA POST
curl -X "POST" \
  "http://$IP_DEFECTDOJO:8080/api/v2/import-scan/" --connect-timeout 10 \
  -H "accept: application/json" \
  -H "Authorization: Token $DEFECTDOJO_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "minimum_severity=Info" \
  -F "active=true" \
  -F "verified=true" \
  -F "scan_type=Trivy Scan" \
  -F "file=@scan.json;type=application/json" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "close_old_findings=false" \
  -F "push_to_jira=false" \
  -F "test_title=Trivy SCA Scan" \
  -F "deduplication_on_engagement=true"

sleep 3

# Trivy License POST
curl -X "POST" \
  "http://$IP_DEFECTDOJO:8080/api/v2/import-scan/" --connect-timeout 10 \
  -H "accept: application/json" \
  -H "Authorization: Token $DEFECTDOJO_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "minimum_severity=Info" \
  -F "active=true" \
  -F "verified=true" \
  -F "scan_type=Trivy Scan" \
  -F "file=@license-scan.json;type=application/json" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "close_old_findings=false" \
  -F "push_to_jira=false" \
  -F "test_title=Trivy License Scan" \
  -F "deduplication_on_engagement=true"

# Semgrep POST
curl -X "POST" \
  "http://$IP_DEFECTDOJO:8080/api/v2/import-scan/" --connect-timeout 10 \
  -H "accept: application/json" \
  -H "Authorization: Token $DEFECTDOJO_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "minimum_severity=Info" \
  -F "active=true" \
  -F "verified=true" \
  -F "scan_type=Semgrep JSON Report" \
  -F "file=@semgrep.json;type=application/json" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "close_old_findings=false" \
  -F "push_to_jira=false" \
  -F "test_title=Semgrep Scan" \
  -F "deduplication_on_engagement=true"

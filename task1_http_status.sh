#!/bin/bash

# ============================================================
# Task 1: HTTP Status Code Checker for guvi.in
# ============================================================

URL="https://guvi.in"

echo "============================================"
echo "   HTTP Status Checker"
echo "============================================"
echo "Checking URL: $URL"
echo ""

# Fetch the HTTP status code using curl
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 10 "$URL")

echo "HTTP Response Code: $HTTP_CODE"
echo ""

# Evaluate the status code and print message
if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" == "000" ]; then
    echo "❌ FAILURE: No response received. The server may be unreachable."

elif [ "$HTTP_CODE" -ge 100 ] && [ "$HTTP_CODE" -le 199 ]; then
    echo "ℹ️  INFORMATIONAL ($HTTP_CODE): Request received, continuing process."

elif [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -le 299 ]; then
    echo "✅ SUCCESS ($HTTP_CODE): The request was successful!"
    case $HTTP_CODE in
        200) echo "    → 200 OK: The page loaded successfully." ;;
        201) echo "    → 201 Created: Resource created successfully." ;;
        204) echo "    → 204 No Content: Success but no content returned." ;;
        *)   echo "    → Request completed successfully." ;;
    esac

elif [ "$HTTP_CODE" -ge 300 ] && [ "$HTTP_CODE" -le 399 ]; then
    echo "🔀 REDIRECTION ($HTTP_CODE): The resource has been moved."
    case $HTTP_CODE in
        301) echo "    → 301 Moved Permanently: URL has permanently changed." ;;
        302) echo "    → 302 Found: Temporary redirect." ;;
        304) echo "    → 304 Not Modified: Cached version is up to date." ;;
        *)   echo "    → Redirection in progress." ;;
    esac

elif [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -le 499 ]; then
    echo "❌ FAILURE - CLIENT ERROR ($HTTP_CODE): The request could not be fulfilled."
    case $HTTP_CODE in
        400) echo "    → 400 Bad Request: The server could not understand the request." ;;
        401) echo "    → 401 Unauthorized: Authentication is required." ;;
        403) echo "    → 403 Forbidden: Access to the resource is denied." ;;
        404) echo "    → 404 Not Found: The requested resource does not exist." ;;
        408) echo "    → 408 Request Timeout: The server timed out waiting." ;;
        429) echo "    → 429 Too Many Requests: Rate limit exceeded." ;;
        *)   echo "    → Client-side error occurred." ;;
    esac

elif [ "$HTTP_CODE" -ge 500 ] && [ "$HTTP_CODE" -le 599 ]; then
    echo "❌ FAILURE - SERVER ERROR ($HTTP_CODE): The server encountered an error."
    case $HTTP_CODE in
        500) echo "    → 500 Internal Server Error: Something went wrong on the server." ;;
        502) echo "    → 502 Bad Gateway: Invalid response from upstream server." ;;
        503) echo "    → 503 Service Unavailable: Server is temporarily down." ;;
        504) echo "    → 504 Gateway Timeout: The server took too long to respond." ;;
        *)   echo "    → Server-side error occurred." ;;
    esac

else
    echo "⚠️  UNKNOWN CODE ($HTTP_CODE): Unrecognized HTTP status code."
fi

echo ""
echo "============================================"
echo "   Check Complete"
echo "============================================"

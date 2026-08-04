#!/bin/bash
# Legacy wrapper for the 7-day view.
exec "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/claude-status.sh" week

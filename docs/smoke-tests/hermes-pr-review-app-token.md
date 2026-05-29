# Hermes PR review GitHub App token smoke test

This harmless document validates that the Hermes PR review webhook can receive a GitHub App `pull_request` event and post the resulting review comment using the GitHub App installation token path.

Expected behavior:

1. GitHub sends a signed `pull_request` webhook for this PR.
2. Hermes receives the event through Cloudflare Tunnel.
3. Hermes creates a GitHub App installation token for the webhook installation.
4. Hermes posts a review-only PR comment.

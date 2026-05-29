# Hermes PR review webhook smoke test

This file is a harmless smoke-test artifact for validating the Hermes GitHub App webhook pipeline.

Expected automation behavior:

1. GitHub sends a `pull_request` webhook when this PR opens or updates.
2. The Cloudflare Tunnel forwards the webhook to the local Hermes PR review daemon.
3. Hermes runs its exact PR review command for this PR.
4. Hermes posts a review-only PR comment.

This file can be removed after the webhook verification is complete.

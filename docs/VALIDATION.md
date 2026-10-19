# v1.0.0 validation

Tested on 2026-10-19 with Apple Silicon, macOS 27.0.1, a built-in display, and a Nextend virtual display to its left.

## Automated checks

- 34 geometry and pointer-takeover checks: negative coordinates, edge boundaries, Option bypass, missing displays, stable UUID selection, main-display changes, covered bottom edges, Dock window geometry, fast clicks, slow movement, and observer failure.
- Native Quartz event-tap start, repeated start, inert pass-through, stop, repeated stop, and restart. These checks use an empty filtering policy and require existing Accessibility access for the test process.
- Optimized Swift build and strict code-signature verification.

## Two-display mechanism experiment

An isolated prototype sent 50 mouse movements to the secondary display's bottom edge in each condition. It did not click or disconnect the display. The pointer and Dock were restored afterward.

| Condition | Suppressed events | Final Dock display |
| --- | ---: | --- |
| No filter | 0 | Secondary display |
| Dock-process-only filter | 10 | Secondary display; this approach was rejected |
| Session event filter | 50 | Primary display |

The released implementation uses the session filter. The final standalone GUI was launched with its own Accessibility permission and reported the Dock fixed to the built-in display. The prototype experiment does not constitute an end-to-end test of every GUI feature.

## Review fixes

- Restore the original pointer position without posting an event that the filter could consume.
- Latch real mouse activity so quick clicks and slow movement cancel relocation.
- Cancel queued relocation requests on pause, screen changes, sleep, user-session changes, and exit.

## Still to verify

Full-screen apps, hot corners, intentional permission revocation, sleep/wake cycles, disconnect/reconnect under load, Intel hardware, and other macOS versions have not been exhaustively tested. No active display session was interrupted for these checks.

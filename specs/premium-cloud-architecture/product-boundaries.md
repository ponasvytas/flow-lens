# Product Boundaries

This matrix defines the initial launch boundary. Capabilities are account-based,
not inferred from the current platform.

## Capability matrix

| Capability | Anonymous free web | Premium web | Premium iOS | Premium Android |
| --- | --- | --- | --- | --- |
| Login required | No | Yes | Yes | Yes |
| Bundled taxonomies | Yes | Yes | Yes | Yes |
| Local preferences | Yes | Cache/fallback | Cache/fallback | Cache/fallback |
| File import/export | Yes | Yes | Yes | Yes |
| Cloud settings | No | Yes | Yes | Yes |
| Saved cloud sessions | No | Yes | Yes | Yes |
| Custom taxonomies | No | Yes | Yes | Yes |
| Create review links | No | Yes | Yes | Yes |
| Open unlisted review links | Yes | Yes | Yes | Yes |
| Uploaded video | No | No | No | No |
| Server-side export | No | No | No | No |

Signed-out mobile clients and premium clients with unavailable auth or
entitlement services fall back to local capabilities. They must not attempt
cloud writes. This fallback is a failure mode, not a separate paid tier.

## Initial premium launch

The minimum premium launch includes:

- Firebase authentication and backend-owned entitlements.
- Cloud settings.
- Saved event and tracking sessions.
- Versioned custom taxonomies.
- Review links containing session metadata and, optionally, an external video
  URL.

Reviewers may open a valid unlisted link without an account. Review links must
remain useful without a playable video.

Uploaded video, server-side export, teams, and organizations are outside the
initial launch. Uploaded video cannot be enabled until quota, retention,
privacy, deletion, cost, and abuse controls are concrete and validated.

## Storage responsibilities

| Data or workflow | Anonymous/free | Premium launch |
| --- | --- | --- |
| Preferences | Local durable storage | Cloud source of truth with local fallback/cache |
| Built-in taxonomy | Bundled asset | Bundled asset |
| Custom taxonomy | Unavailable | Cloud source of truth with versioned local cache later |
| Event/tracking session | In-memory plus JSON import/export | Cloud source of truth plus JSON import/export |
| Entitlement | Unavailable | Backend source of truth; local state is never authoritative |
| Video | User-selected local file or URL | Same for initial launch |

File import/export is a user-directed interchange workflow. It is not the
durable repository for premium account data.

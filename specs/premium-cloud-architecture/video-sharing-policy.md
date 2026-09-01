# Video Sharing Policy

Video sharing is the highest-cost and highest-risk part of the premium plan. It
should be designed after metadata-only review links and before any production
video upload feature ships.

## Sharing modes

### Metadata-only review links

The shared link contains event or tracking data. Reviewers provide the same video
locally or use their own video source.

Benefits:

- Lowest cost.
- Lowest legal and privacy risk.
- Fastest MVP.

Limitations:

- Reviewer experience is less smooth.
- Video and events can drift if the wrong source video is loaded.

### External video URL review links

The shared link references an externally hosted video URL.

Benefits:

- Low hosting cost for Flow Lens.
- Better reviewer experience than metadata-only.

Limitations:

- External URLs may expire, require auth, or block cross-origin playback.
- Users can paste URLs they do not have rights to share.
- Flow Lens has limited control over reliability.

### Uploaded video review links

Flow Lens hosts the video and event data.

Benefits:

- Best reviewer experience.
- Enables server-side export and consistent playback.

Risks:

- Storage and bandwidth cost can grow quickly.
- Privacy and youth sports consent concerns become more serious.
- Requires terms, abuse reporting, deletion, retention, and moderation paths.
- Large uploads create mobile and web reliability concerns.

## Recommended rollout

1. Start with metadata-only or external-URL review links.
2. Add uploaded video only after quota and policy controls are ready.
3. Treat uploaded video as premium-plus or usage-metered until real cost data is
   available.

## Upload controls required before launch

- Per-file size limit.
- Per-account storage quota.
- Monthly bandwidth or viewing limits if needed.
- Supported file types and content types.
- Maximum retention period for inactive videos.
- User deletion workflow.
- Account deletion cleanup workflow.
- Abuse report workflow.
- Terms acceptance before upload.
- Clear prohibition on illegal, infringing, or non-consensual content.
- Admin ability to block or delete assets.

## Initial quota assumptions

These are placeholders for planning, not product commitments:

- Base premium: no uploaded video, or very small trial quota.
- Premium-plus: limited number of active videos and capped total GB.
- Higher tiers: larger storage with explicit pricing.

The app should measure asset size, asset count, and bandwidth-related usage so
the business can revise limits from real data.

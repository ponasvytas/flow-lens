# Phase 07 - Video assets and export

## Objective

Add optional uploaded-video hosting and server-side export only after cost,
privacy, quota, and security controls are ready.

## Prerequisites

- Phase 06 review links are complete.
- [../video-sharing-policy.md](../video-sharing-policy.md) has concrete quotas,
  retention, and abuse controls.
- Firebase Storage or alternate asset storage is selected.
- Server-side export runtime is selected, such as Cloud Functions or Cloud Run.

## Implementation

- Add `VideoAssetRepository` only when upload is in scope.
- Enforce per-account quotas and per-file size limits.
- Store video metadata separately from binary assets.
- Add terms acceptance before upload.
- Add delete, retention, and account cleanup workflows.
- Add admin block/delete capability for abuse handling.
- Add server-side export as a separate premium capability.
- Keep browser-side web export limitations clear.

## API changes

- Video asset metadata model.
- Upload status model.
- Quota usage model.
- Server export job model.

## Failure handling

- Upload interrupted: asset remains `uploading` or `failed` and can be retried
  or cleaned up.
- Quota exceeded: block upload before binary transfer when possible.
- Asset blocked: review links must stop serving the video.
- Export failed: preserve diagnostics and allow retry if inputs are still valid.

## Tests

- Storage rules enforce owner paths and read permissions.
- Quota checks deny excess uploads.
- Deleted or blocked assets are not publicly readable.
- Server export rejects unauthorized jobs.
- Cleanup jobs handle orphaned upload records.

## Acceptance checklist

- [ ] Uploaded video has explicit quotas and retention.
- [ ] Terms and prohibited-content policy exist before upload.
- [ ] Storage rules pass emulator tests.
- [ ] Review links can use uploaded assets safely.
- [ ] Server-side export is entitlement-gated.

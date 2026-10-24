# rollouts-demo

`argoproj/rollouts-demo:<color>` is the official Argo Rollouts demo image. Each tag (`blue`,
`green`, `yellow`, `red`, `purple`, `orange`, `bad-red` ...) serves a page that fills with squares
of that colour, so you can *see* which ReplicaSet is receiving traffic during a blue-green or canary
rollout. `bad-red` returns 500s on purpose, which is handy for analysis labs.

The rollout labs (02, 03, 04) define their own Rollout objects; this folder only documents the image.

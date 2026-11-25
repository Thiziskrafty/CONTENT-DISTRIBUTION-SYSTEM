BEGIN;
CREATE TABLE IF NOT EXISTS songs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, title text NOT NULL, audio_path text NOT NULL, lyrics text, bpm numeric CHECK(bpm>0), duration_seconds numeric CHECK(duration_seconds>0), analysis jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS campaigns (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, song_id bigint NOT NULL REFERENCES songs(id), name text NOT NULL, audience text, creative_direction jsonb NOT NULL DEFAULT '{}', target_clips integer NOT NULL DEFAULT 500 CHECK(target_clips BETWEEN 1 AND 10000), status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','paused','complete')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS trends (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, platform text NOT NULL, external_id text NOT NULL, url text NOT NULL, format text, tags text[] NOT NULL DEFAULT '{}', observations jsonb NOT NULL DEFAULT '{}', observed_at timestamptz NOT NULL DEFAULT now(), UNIQUE(platform,external_id)
);
CREATE TABLE IF NOT EXISTS trend_observations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, trend_id bigint NOT NULL REFERENCES trends(id), observed_at timestamptz NOT NULL DEFAULT now(), metrics jsonb NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS footage (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, source_url text, local_path text, sha256 text UNIQUE, title text NOT NULL, source_platform text, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS footage_rights (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, footage_id bigint NOT NULL REFERENCES footage(id), status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','revoked')), evidence text, commercial_use boolean NOT NULL DEFAULT false, editing_allowed boolean NOT NULL DEFAULT false, platforms text[] NOT NULL DEFAULT '{}', valid_until timestamptz, reviewed_at timestamptz NOT NULL DEFAULT now(), CHECK(status <> 'approved' OR (evidence IS NOT NULL AND commercial_use AND editing_allowed))
);
CREATE TABLE IF NOT EXISTS scenes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, footage_id bigint NOT NULL REFERENCES footage(id), start_seconds numeric NOT NULL CHECK(start_seconds>=0), end_seconds numeric NOT NULL, tags text[] NOT NULL DEFAULT '{}', analysis jsonb NOT NULL DEFAULT '{}', fingerprint text, CHECK(end_seconds>start_seconds), UNIQUE(footage_id,start_seconds,end_seconds)
);
CREATE TABLE IF NOT EXISTS campaign_scenes (
 campaign_id bigint REFERENCES campaigns(id), scene_id bigint REFERENCES scenes(id), relevance numeric CHECK(relevance BETWEEN 0 AND 100), rationale text, PRIMARY KEY(campaign_id,scene_id)
);
CREATE TABLE IF NOT EXISTS creative_formats (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL UNIQUE, description text, configuration jsonb NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS clips (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, campaign_id bigint NOT NULL REFERENCES campaigns(id), scene_id bigint NOT NULL REFERENCES scenes(id), format_id bigint REFERENCES creative_formats(id), recipe jsonb NOT NULL DEFAULT '{}', recipe_hash text NOT NULL UNIQUE, output_path text, fingerprint text, review_status text NOT NULL DEFAULT 'pending' CHECK(review_status IN ('pending','approved','rejected')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS render_jobs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, clip_id bigint NOT NULL UNIQUE REFERENCES clips(id), status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','succeeded','failed','cancelled')), attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), available_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz, worker_id text, last_error text, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS render_queue_idx ON render_jobs(status,available_at);
CREATE TABLE IF NOT EXISTS social_accounts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, platform text NOT NULL, account_ref text NOT NULL, display_name text, active boolean NOT NULL DEFAULT true, UNIQUE(platform,account_ref)
);
CREATE TABLE IF NOT EXISTS publications (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, clip_id bigint NOT NULL REFERENCES clips(id), account_id bigint NOT NULL REFERENCES social_accounts(id), external_post_id text, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','approved','scheduled','published','failed','cancelled')), scheduled_at timestamptz, published_at timestamptz, UNIQUE(clip_id,account_id), UNIQUE(account_id,external_post_id)
);
CREATE TABLE IF NOT EXISTS performance_snapshots (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, publication_id bigint NOT NULL REFERENCES publications(id), observed_at timestamptz NOT NULL DEFAULT now(), views bigint CHECK(views>=0), likes bigint CHECK(likes>=0), shares bigint CHECK(shares>=0), comments bigint CHECK(comments>=0), watch_seconds numeric CHECK(watch_seconds>=0), extra jsonb NOT NULL DEFAULT '{}', UNIQUE(publication_id,observed_at)
);
CREATE TABLE IF NOT EXISTS monthly_budgets (
 month date PRIMARY KEY CHECK(EXTRACT(DAY FROM month)=1), limit_pence integer NOT NULL DEFAULT 2500 CHECK(limit_pence>=0)
);
CREATE TABLE IF NOT EXISTS cost_entries (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, month date NOT NULL REFERENCES monthly_budgets(month), campaign_id bigint REFERENCES campaigns(id), category text NOT NULL, amount_pence integer NOT NULL CHECK(amount_pence>=0), state text NOT NULL CHECK(state IN ('reserved','settled','released')), idempotency_key text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cost_month_idx ON cost_entries(month,state);
CREATE TABLE IF NOT EXISTS audit_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, event_type text NOT NULL, entity_type text NOT NULL, entity_id bigint, details jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS scenes_tags_idx ON scenes USING gin(tags);
CREATE INDEX IF NOT EXISTS clips_campaign_idx ON clips(campaign_id,review_status);
CREATE INDEX IF NOT EXISTS performance_post_idx ON performance_snapshots(publication_id,observed_at DESC);
COMMIT;

BEGIN;
CREATE OR REPLACE VIEW eligible_footage AS
SELECT f.*, r.platforms, r.valid_until FROM footage f
JOIN LATERAL (SELECT * FROM footage_rights WHERE footage_id=f.id ORDER BY reviewed_at DESC,id DESC LIMIT 1) r ON true
WHERE r.status='approved' AND r.commercial_use AND r.editing_allowed AND (r.valid_until IS NULL OR r.valid_until>now());

CREATE OR REPLACE FUNCTION reserve_cost(p_month date,p_campaign bigint,p_category text,p_amount integer,p_key text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE cap integer; used bigint; existing cost_entries%ROWTYPE; result_id bigint;
BEGIN
 IF p_amount IS NULL OR p_amount<0 OR p_key IS NULL THEN RAISE EXCEPTION 'Invalid reservation'; END IF;
 INSERT INTO monthly_budgets(month) VALUES(p_month) ON CONFLICT DO NOTHING;
 SELECT limit_pence INTO cap FROM monthly_budgets WHERE month=p_month FOR UPDATE;
 SELECT * INTO existing FROM cost_entries WHERE idempotency_key=p_key;
 IF FOUND THEN
  IF existing.month<>p_month OR existing.campaign_id IS DISTINCT FROM p_campaign OR existing.category<>p_category OR existing.amount_pence<>p_amount OR existing.state='released' THEN RAISE EXCEPTION 'Reservation key conflict'; END IF;
  RETURN existing.id;
 END IF;
 SELECT COALESCE(sum(amount_pence),0) INTO used FROM cost_entries WHERE month=p_month AND state IN ('reserved','settled');
 IF used+p_amount>cap THEN RAISE EXCEPTION 'Monthly budget exceeded'; END IF;
 INSERT INTO cost_entries(month,campaign_id,category,amount_pence,state,idempotency_key) VALUES(p_month,p_campaign,p_category,p_amount,'reserved',p_key) RETURNING id INTO result_id;
 RETURN result_id;
END $$;

CREATE OR REPLACE FUNCTION claim_render_job(p_worker text)
RETURNS SETOF render_jobs LANGUAGE sql AS $$
 UPDATE render_jobs j SET status='running',worker_id=p_worker,attempts=j.attempts+1,lease_until=now()+interval '15 minutes',updated_at=now()
 WHERE j.id=(SELECT q.id FROM render_jobs q JOIN clips c ON c.id=q.clip_id JOIN scenes s ON s.id=c.scene_id JOIN eligible_footage f ON f.id=s.footage_id JOIN campaigns ca ON ca.id=c.campaign_id WHERE ca.status='active' AND c.review_status<>'rejected' AND q.attempts<3 AND ((q.status='queued' AND q.available_at<=now()) OR (q.status='running' AND q.lease_until<now())) ORDER BY q.available_at,q.id LIMIT 1 FOR UPDATE OF q SKIP LOCKED)
 RETURNING j.*;
$$;
CREATE OR REPLACE VIEW monthly_spend AS
SELECT b.month,b.limit_pence,COALESCE(sum(c.amount_pence) FILTER(WHERE c.state='settled'),0) AS settled_pence,COALESCE(sum(c.amount_pence) FILTER(WHERE c.state='reserved'),0) AS reserved_pence
FROM monthly_budgets b LEFT JOIN cost_entries c ON c.month=b.month GROUP BY b.month,b.limit_pence;
CREATE OR REPLACE VIEW latest_performance AS
SELECT DISTINCT ON(publication_id) * FROM performance_snapshots ORDER BY publication_id,observed_at DESC,id DESC;
CREATE OR REPLACE VIEW format_performance AS
SELECT c.format_id,p.account_id,count(*) AS measured_posts,avg(m.views) AS avg_views,avg(m.shares) AS avg_shares,avg(m.watch_seconds) AS avg_watch_seconds
FROM publications p JOIN clips c ON c.id=p.clip_id JOIN latest_performance m ON m.publication_id=p.id WHERE p.status='published' GROUP BY c.format_id,p.account_id;
COMMIT;

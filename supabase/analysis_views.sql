-- Per-instrument analysis views.
--
-- Run this in the Supabase SQL editor. Safe to re-run: every view is
-- CREATE OR REPLACE and nothing here writes, alters or drops data.
--
-- ---------------------------------------------------------------------
-- WHY VIEWS AND NOT TABLES
--
-- A view is a saved query, not a copy. It reads the live rows every time,
-- so it cannot fall behind and there is nothing to keep in sync. Separate
-- TABLES would mean copying rows out and re-copying them after every study
-- day — a second source of truth that drifts the first time someone forgets,
-- and drifts silently. In the Table Editor these appear alongside the tables
-- and can be browsed, sorted and exported the same way.
--
-- ---------------------------------------------------------------------
-- NOTHING HERE IS READABLE FROM A BROWSER
--
-- A view runs with its owner's rights, which is exactly how `leaderboard`
-- deliberately exposes display_name and score out of an otherwise unreadable
-- `scores` table. That makes an un-revoked view a hole straight through
-- row-level security. Every view below is therefore revoked from `anon` and
-- `authenticated`: they are for you, in the SQL editor or the Table Editor,
-- signed in as yourself. `leaderboard` remains the only thing a student's
-- browser can read. The last query in this file checks that.
--
-- ---------------------------------------------------------------------
-- HOW THE TWO INSTRUMENTS ARE TOLD APART
--
-- The data was never actually mixed. `sessions.instrument` and
-- `events.instrument` carry 'rowdyrobo' or 'ctx3', defaulting to 'rowdyrobo'
-- precisely because RowdyRoboVac's client does not write the column, and
-- rows predating it were backfilled. Within CTx3, `events.tool` names the
-- activity: 'hub', 'alwaysnever', 'prompt-golf', 'monstermaker'.
--
-- So: RowdyRoboVac  = instrument 'rowdyrobo'
--     MonsterMaker  = instrument 'ctx3' AND tool 'monstermaker'
-- ---------------------------------------------------------------------


-- =====================================================================
-- RowdyRoboVac
-- =====================================================================

-- One row per participant. `ended` and `completed` are derived from the
-- session_end event rather than read from the columns of the same name,
-- which stay null by design because the client is never granted UPDATE.
create or replace view rowdyrobo_sessions as
select
  s.id,
  s.participant_code,
  s.first_name,
  s.last_initial,
  s.grade,
  min(e.server_ts) filter (where e.type = 'session_start') as started,
  max(e.server_ts) filter (where e.type = 'session_end')   as ended,
  bool_or(e.type = 'session_end')                          as completed,
  count(e.id)                                              as event_count,
  s.user_agent
from sessions s
left join events e
  on e.session_id = s.id
 and e.instrument = 'rowdyrobo'
where s.instrument = 'rowdyrobo'
group by s.id;


-- One row per level finished: how long it took and how much got cleaned.
-- `performance` is the fraction of trash collected when the phase ended.
create or replace view rowdyrobo_phases as
select
  e.session_id,
  s.participant_code,
  s.first_name,
  e.payload->>'phase'                                  as phase,
  (e.payload->>'duration')::numeric                    as seconds,
  (e.payload->>'performance')::numeric                 as performance,
  (e.payload->>'trash_collected')::int                 as trash_collected,
  (e.payload->>'trash_total')::int                     as trash_total,
  e.payload->'code'                                    as code,
  e.server_ts
from events e
join sessions s on s.id = e.session_id
where e.instrument = 'rowdyrobo'
  and e.type = 'phase_complete';


-- Every program a student ran or submitted, in order. `code` is an array of
-- Global.CodeAction integers; join it to rowdyrobo_block_names to read it.
-- This is the computational-thinking signal: how many times they pressed
-- play before submitting, and what changed in between.
create or replace view rowdyrobo_programs as
select
  e.session_id,
  s.participant_code,
  s.first_name,
  e.payload->>'phase'                                           as phase,
  e.type                                                        as moment,
  e.payload->'code'                                             as code,
  jsonb_array_length(coalesce(e.payload->'code', '[]'::jsonb))  as blocks,
  e.seq,
  e.server_ts
from events e
join sessions s on s.id = e.session_id
where e.instrument = 'rowdyrobo'
  and e.type in ('code_run', 'code_submit');


-- The enum, so a program reads as words instead of numbers. These values are
-- frozen in the game (tools/check_all.gd enforces it), so this mapping is
-- safe to rely on.
create or replace view rowdyrobo_block_names as
select * from (values
  (1,  'Move forward'),
  (2,  'Move backward'),
  (3,  'Move randomly'),
  (4,  'Turn right'),
  (5,  'Turn left'),
  (6,  'Turn around'),
  (7,  'Turn randomly'),
  (8,  'If obstacle ahead'),
  (9,  'If obstacle right'),
  (10, 'If obstacle left'),
  (11, 'If cleaned ahead'),
  (12, 'If cleaned right'),
  (13, 'If cleaned left')
) as t(action_id, block);


-- =====================================================================
-- CTx3 — MonsterMaker
-- =====================================================================

-- One row per student who used MonsterMaker. A CTx3 session can span several
-- activities, so this counts only the MonsterMaker part of it.
create or replace view monstermaker_sessions as
select
  s.id,
  s.participant_code,
  s.first_name,
  s.last_initial,
  s.grade,
  min(e.server_ts)                                      as first_seen,
  max(e.server_ts)                                      as last_seen,
  count(*)                                              as event_count,
  count(*) filter (where e.type = 'attempt_submitted')  as attempts,
  count(*) filter (where e.type = 'attempt_evaluated')  as evaluations,
  count(*) filter (where e.type = 'support_used')       as supports_used,
  bool_or(e.type = 'task_complete')                     as completed
from sessions s
join events e on e.session_id = s.id
where e.instrument = 'ctx3'
  and e.tool = 'monstermaker'
group by s.id;


-- Everything MonsterMaker recorded, newest payload kept whole. The payload
-- shape varies by event type, so it stays JSONB rather than being flattened
-- into columns that would be null most of the time.
create or replace view monstermaker_events as
select
  e.session_id,
  s.participant_code,
  s.first_name,
  e.type,
  e.payload,
  e.seq,
  e.device_id,
  e.client_ts,
  e.server_ts
from events e
join sessions s on s.id = e.session_id
where e.instrument = 'ctx3'
  and e.tool = 'monstermaker';


-- =====================================================================
-- Lock them away from the browser
-- =====================================================================

revoke all on rowdyrobo_sessions     from anon, authenticated;
revoke all on rowdyrobo_phases       from anon, authenticated;
revoke all on rowdyrobo_programs     from anon, authenticated;
revoke all on rowdyrobo_block_names  from anon, authenticated;
revoke all on monstermaker_sessions  from anon, authenticated;
revoke all on monstermaker_events    from anon, authenticated;


-- ---------------------------------------------------------------------
-- CHECK THIS BY HAND after running the file. `leaderboard` must be the only
-- row that comes back. Anything else listed here is readable with the key
-- that ships inside the game.
--
--   select table_name
--   from information_schema.role_table_grants
--   where grantee = 'anon' and privilege_type = 'SELECT';
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- Starters
--
-- Who played what, across both tools:
--
--   select 'rowdyrobo' as tool, participant_code, first_name, completed
--   from rowdyrobo_sessions
--   union all
--   select 'monstermaker', participant_code, first_name, completed
--   from monstermaker_sessions
--   order by participant_code;
--
-- A student's RowdyRoboVac program, in words:
--
--   select p.participant_code, p.phase, p.moment, p.seq,
--          (select string_agg(b.block, ' -> ' order by i.ord)
--           from jsonb_array_elements_text(p.code) with ordinality i(val, ord)
--           join rowdyrobo_block_names b on b.action_id = i.val::int) as program
--   from rowdyrobo_programs p
--   where p.moment = 'code_submit'
--   order by p.participant_code, p.seq;
--
-- Runs before submitting, per level — iterate-and-retry:
--
--   select phase,
--          count(*) filter (where moment = 'code_run')    as runs,
--          count(*) filter (where moment = 'code_submit') as submits
--   from rowdyrobo_programs group by phase order by phase;
-- ---------------------------------------------------------------------

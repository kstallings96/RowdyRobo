-- RowdyRoboVac — database schema.
--
-- Run this once in the Supabase SQL editor. It is safe to re-run.
--
-- Three tables. Identifying data about minors lives in `sessions` and nowhere
-- else; `events` carries only phase names, code-block sequences and timings, so
-- the behavioural data can be shared or analysed without carrying names.
-- `scores` exists only to feed the end-of-game leaderboard.

create table if not exists sessions (
  id uuid primary key,
  first_name text not null,
  last_initial text not null,
  grade text not null,
  user_agent text,
  screen_w int,
  screen_h int,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  completed boolean not null default false
);

-- One append-only table with a JSONB payload rather than a table per event
-- type. You will think of an analysis in March that you did not plan for in
-- September, and JSONB can answer it.
create table if not exists events (
  id bigserial primary key,
  session_id uuid not null references sessions(id),
  seq int not null,
  type text not null,
  payload jsonb not null default '{}',
  client_ts timestamptz not null,
  server_ts timestamptz not null default now(),
  unique (session_id, seq)
);

create index if not exists events_session_seq_idx on events (session_id, seq);
create index if not exists events_type_idx on events (type);

-- The leaderboard's backing store. Deliberately separate from `sessions`: it
-- holds the first name the student already sees on screen and a percentage,
-- and nothing else that could be read back.
create table if not exists scores (
  id bigserial primary key,
  session_id uuid not null references sessions(id),
  display_name text not null,
  score numeric not null,
  created_at timestamptz not null default now()
);

create index if not exists scores_score_idx on scores (score desc);

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- The anon key ships inside the client build and anyone can read it out of
-- devtools. RLS is the only thing stopping one student reading every other
-- student's session. Insert is granted; select, update and delete are not.
-- You read the data with the service_role key, from your own machine only.
-- ---------------------------------------------------------------------------

alter table sessions enable row level security;
alter table events   enable row level security;
alter table scores   enable row level security;

drop policy if exists anon_insert_sessions on sessions;
drop policy if exists anon_insert_events   on events;
drop policy if exists anon_insert_scores   on scores;

create policy anon_insert_sessions on sessions for insert to anon with check (true);
create policy anon_insert_events   on events   for insert to anon with check (true);
create policy anon_insert_scores   on scores   for insert to anon with check (true);

-- ---------------------------------------------------------------------------
-- The one read path
--
-- The game ends on a leaderboard, so something has to be readable. This view
-- is owned by postgres and so bypasses RLS on `scores`, while `scores` itself
-- stays unreadable to anon. The result: anon can read exactly what the end
-- screen already shows on the projector — a first name and a percentage — and
-- cannot reach session_id, grades, timings or code history.
--
-- Do not add a select policy to `scores` itself. That would expose session_id,
-- which joins a score back to a named student.
-- ---------------------------------------------------------------------------

create or replace view leaderboard as
  select display_name, score, created_at
  from scores;

alter view leaderboard set (security_invoker = off);

grant select on leaderboard to anon;

-- Verify by hand after running this. All three rows must show rowsecurity = true.
--
--   select tablename, rowsecurity from pg_tables
--   where schemaname = 'public' and tablename in ('sessions', 'events', 'scores');
--
-- And confirm the read boundary holds, using the ANON key, not the SQL editor:
--
--   select * from sessions;    -- must return 0 rows
--   select * from events;      -- must return 0 rows
--   select * from scores;      -- must return 0 rows
--   select * from leaderboard; -- must return rows

-- ---------------------------------------------------------------------------
-- Analysis starters
--
-- `sessions.ended_at` and `completed` stay null by design: the client is not
-- granted UPDATE, so completion is derived from the session_end event rather
-- than written back.
-- ---------------------------------------------------------------------------

-- One row per participant, with derived timing.
--
--   select s.id, s.first_name, s.last_initial, s.grade,
--          min(e.server_ts) filter (where e.type = 'session_start') as started,
--          max(e.server_ts) filter (where e.type = 'session_end')   as ended,
--          bool_or(e.type = 'session_end')                          as completed
--   from sessions s left join events e on e.session_id = s.id
--   group by s.id order by started;

-- Time and performance per phase. `performance` is the fraction of trash
-- collected when the phase ended.
--
--   select payload->>'phase' as phase,
--          count(*)                                as runs,
--          avg((payload->>'duration')::numeric)    as avg_seconds,
--          avg((payload->>'performance')::numeric) as avg_performance
--   from events where type = 'phase_complete'
--   group by 1 order by 1;

-- How many times a student ran their program before submitting — the
-- iterate-and-retry signal.
--
--   select e.session_id,
--          payload->>'phase' as phase,
--          count(*) filter (where e.type = 'code_run')    as runs,
--          count(*) filter (where e.type = 'code_submit') as submits
--   from events e
--   where e.type in ('code_run', 'code_submit')
--   group by 1, 2 order by 1, 2;

-- The actual programs students wrote. `code` is an array of Global.CodeAction
-- enum values, in slot order.
--
--   select session_id, payload->>'phase' as phase, payload->'code' as code
--   from events where type = 'code_submit'
--   order by session_id, seq;

-- Did anyone get stranded? A session with events but no session_end either
-- crashed, ran out of class time, or closed the tab.
--
--   select s.id, s.first_name, count(e.id) as events
--   from sessions s join events e on e.session_id = s.id
--   group by s.id, s.first_name
--   having not bool_or(e.type = 'session_end')
--   order by events desc;

-- ---------------------------------------------------------------------
-- PARTICIPANT CODES  (added when the week moved to one shared key)
--
-- THE CANONICAL FILE IS CTx3'S. This project's database is now shared with
-- CTx3, and `ctx3/supabase/schema.sql` is the file that describes the whole
-- thing — both instruments' columns, the per-instrument dedup indexes, and the
-- RLS posture. Run THAT file; this section exists so a database built from
-- this file alone still has a roster, and so the two do not silently disagree.
--
-- Students sign in with a code printed on a card — ABC123, three letters and
-- three digits. The same code identifies that student in VibeBuilder and CTx3,
-- which is what lets the week's data join on one key. The code is collected
-- alongside the name, not instead of it: `sessions.first_name` is still how a
-- teacher matches a device to a paper packet.
-- ---------------------------------------------------------------------
alter table sessions add column if not exists participant_code text;
alter table events   add column if not exists participant_code text;

create index if not exists events_code_idx on events (participant_code, seq);

create table if not exists students (
  username   text primary key,          -- ABC123
  role       text not null default 'student',   -- 'student' | 'instructor'
  cohort     text,
  created_at timestamptz not null default now()
);

alter table students add column if not exists role text not null default 'student';

-- Same posture as every other table here: RLS on, no policies for anon, so the
-- roster cannot be read or enumerated from a browser. Validation goes through
-- the function below, which answers one yes/no question and returns no rows.
alter table students enable row level security;
revoke all on students from anon, authenticated;

create or replace function check_roster(code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from students
    where username = upper(regexp_replace(coalesce(code, ''), '[^A-Za-z0-9]', '', 'g'))
  );
$$;

revoke all on function check_roster(text) from public;
grant execute on function check_roster(text) to anon;

-- The instructor key. KSS17 opens every tool in the week and is a different
-- shape from a student code (three letters, two digits) so it can never
-- collide with a printed card. Its rows are real rows — exclude them in
-- analysis rather than assuming they are not there:
--
--   where participant_code <> 'KSS17'
insert into students (username, role) values ('KSS17', 'instructor')
on conflict (username) do update set role = 'instructor';

-- DELIBERATELY NO FOREIGN KEY from sessions.participant_code to students. A
-- foreign key would make an unseeded or misspelled code a hard insert failure,
-- costing that student their entire session — the one failure this study
-- cannot absorb. The game checks the roster at sign-in and warns; if the check
-- cannot be reached, sign-in proceeds anyway, because a classroom with no wifi
-- still has to be able to run the study.
--
-- Find the bad ones in analysis instead:
--
--   select distinct participant_code from sessions
--   where participant_code is not null
--     and participant_code not in (select username from students);

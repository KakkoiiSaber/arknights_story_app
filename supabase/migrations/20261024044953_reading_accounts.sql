-- One setting per row prevents unrelated settings from overwriting each other.
create table public.user_settings (
  user_id uuid not null references auth.users(id) on delete cascade,
  setting_key text not null check (setting_key in ('doctorName', 'fontScale', 'typingIntervalMs')),
  value jsonb not null check (jsonb_typeof(value) = 'object'),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, setting_key)
);
create table public.chapter_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_id text not null check (length(chapter_id) between 1 and 512),
  value jsonb not null check (jsonb_typeof(value) = 'object'),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, chapter_id)
);
create table public.reading_resume (
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id text not null check (length(story_id) between 1 and 256),
  value jsonb not null check (jsonb_typeof(value) = 'object'),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, story_id)
);

alter table public.user_settings enable row level security;
alter table public.chapter_progress enable row level security;
alter table public.reading_resume enable row level security;

create policy settings_select on public.user_settings for select to authenticated using ((select auth.uid()) = user_id);
create policy settings_insert on public.user_settings for insert to authenticated with check ((select auth.uid()) = user_id);
create policy settings_update on public.user_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy chapter_select on public.chapter_progress for select to authenticated using ((select auth.uid()) = user_id);
create policy chapter_insert on public.chapter_progress for insert to authenticated with check ((select auth.uid()) = user_id);
create policy chapter_update on public.chapter_progress for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy resume_select on public.reading_resume for select to authenticated using ((select auth.uid()) = user_id);
create policy resume_insert on public.reading_resume for insert to authenticated with check ((select auth.uid()) = user_id);
create policy resume_update on public.reading_resume for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.user_settings, public.chapter_progress, public.reading_resume from anon;
grant select, insert, update on public.user_settings, public.chapter_progress, public.reading_resume to authenticated;

-- Explicit owner predicates plus RLS; never executes with elevated privileges.
-- Returning the current row on conflict keeps stale offline bookmarks from
-- overwriting a newer device. Clients may merge monotonic completion facts.
create function public.sync_reading_records(mutations jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  item jsonb;
  table_name text;
  key_column text;
  row_value jsonb;
  row_revision bigint;
  base_revision bigint;
  did_conflict boolean;
  affected integer;
  result jsonb := '[]'::jsonb;
begin
  if owner_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if jsonb_typeof(mutations) <> 'array' or jsonb_array_length(mutations) > 50 then
    raise exception 'Invalid batch';
  end if;
  -- Stable lock ordering prevents competing devices from deadlocking.
  for item in select value from jsonb_array_elements(mutations) order by value->>'kind', value->>'key' loop
    case item->>'kind'
      when 'setting' then table_name := 'user_settings'; key_column := 'setting_key';
      when 'chapter' then table_name := 'chapter_progress'; key_column := 'chapter_id';
      when 'resume' then table_name := 'reading_resume'; key_column := 'story_id';
      else raise exception 'Invalid record kind';
    end case;
    if length(item->>'key') not between 1 and 512 or
       jsonb_typeof(item->'value') <> 'object' or pg_column_size(item->'value') > 262144 then
      raise exception 'Invalid record';
    end if;
    base_revision := (item->>'base_revision')::bigint;
    if base_revision is null or base_revision < 0 then raise exception 'Invalid revision'; end if;
    if base_revision = 0 then
      execute format('insert into public.%I(user_id, %I, value) values ($1, $2, $3) on conflict do nothing', table_name, key_column)
        using owner_id, item->>'key', item->'value';
      get diagnostics affected = row_count;
      did_conflict := affected = 0;
    else did_conflict := false;
    end if;
    execute format('select value, revision from public.%I where user_id=$1 and %I=$2 for update', table_name, key_column)
      into row_value, row_revision using owner_id, item->>'key';
    if row_revision is null then raise exception 'Record no longer exists'; end if;
    if base_revision > 0 then
      did_conflict := row_revision <> base_revision;
      if not did_conflict then
        execute format('update public.%I set value=$3, revision=revision+1, updated_at=now() where user_id=$1 and %I=$2 returning value, revision', table_name, key_column)
          into row_value, row_revision using owner_id, item->>'key', item->'value';
      end if;
    end if;
    result := result || jsonb_build_array(jsonb_build_object(
      'kind', item->>'kind', 'key', item->>'key', 'value', row_value,
      'revision', row_revision, 'conflict', did_conflict));
  end loop;
  return result;
end;
$$;
revoke all on function public.sync_reading_records(jsonb) from public, anon;
grant execute on function public.sync_reading_records(jsonb) to authenticated;

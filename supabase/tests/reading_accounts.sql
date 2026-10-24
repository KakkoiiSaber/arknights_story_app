-- Run in the SQL Editor after deploying reading_accounts. Fixtures exist only
-- in this transaction: no permanent test users, emails, or reading records.
begin;
select set_config('arkstory.test_user_a', gen_random_uuid()::text, true);
select set_config('arkstory.test_user_b', gen_random_uuid()::text, true);
insert into auth.users(id) values
  (current_setting('arkstory.test_user_a')::uuid),
  (current_setting('arkstory.test_user_b')::uuid);

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('arkstory.test_user_a'), true);
do $$
declare response jsonb;
begin
  response := public.sync_reading_records('[{"kind":"setting","key":"doctorName","base_revision":0,"value":{"value":"test-a"}}]');
  assert (response->0->>'revision')::int = 1, 'initial revision';
  assert (response->0->>'conflict')::boolean = false, 'initial insert';
  response := public.sync_reading_records('[{"kind":"setting","key":"doctorName","base_revision":1,"value":{"value":"test-a-new"}}]');
  assert (response->0->>'revision')::int = 2, 'update revision';
  response := public.sync_reading_records('[{"kind":"setting","key":"doctorName","base_revision":1,"value":{"value":"stale"}}]');
  assert (response->0->>'conflict')::boolean, 'stale write detected';
  assert response->0->'value'->>'value' = 'test-a-new', 'stale write preserved server value';
  perform public.sync_reading_records('[{"kind":"chapter","key":"obt/test","base_revision":0,"value":{"completed":true}},{"kind":"resume","key":"test-story","base_revision":0,"value":{"chapterId":"obt/test"}}]');
end;
$$;

select set_config('request.jwt.claim.sub', current_setting('arkstory.test_user_b'), true);
do $$
begin
  assert not exists(select 1 from public.user_settings), 'settings isolated';
  assert not exists(select 1 from public.chapter_progress), 'chapters isolated';
  assert not exists(select 1 from public.reading_resume), 'resume isolated';
  begin
    insert into public.user_settings(user_id, setting_key, value)
      values(current_setting('arkstory.test_user_a')::uuid, 'fontScale', '{"value":1}');
    raise exception 'RLS permitted another owner';
  exception when insufficient_privilege then null;
  end;
  perform public.sync_reading_records('[{"kind":"setting","key":"doctorName","base_revision":0,"value":{"value":"test-b"}}]');
  assert (select value->>'value' from public.user_settings where setting_key='doctorName') = 'test-b', 'second account writes its own row';
end;
$$;

reset role;
do $$
begin
  assert not has_function_privilege('anon', 'public.sync_reading_records(jsonb)', 'execute'), 'anonymous RPC denied';
  assert (select count(*) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('user_settings','chapter_progress','reading_resume') and c.relrowsecurity) = 3, 'all tables have RLS';
end;
$$;
rollback;
select 'PASS: revisions, stale-device conflict, cross-account RLS and anonymous RPC checks; all fixtures rolled back' as result;

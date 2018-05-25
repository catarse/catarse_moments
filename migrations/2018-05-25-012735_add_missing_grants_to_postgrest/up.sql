-- Your SQL goes here
ALTER TABLE ONLY moment_service.moments ALTER COLUMN id SET DEFAULT nextval('moment_service.moments_id_seq'::regclass);
grant usage on schema moment_service_api to postgrest;
grant usage on schema moment_service to postgrest;
grant execute on function moment_service_api.track(jsonb) to web_user, anonymous, admin;
grant usage on schema moment_service to web_user, anonymous, admin;
grant usage on schema moment_service_api to web_user, anonymous, admin;
grant usage on sequence moment_service.moments_id_seq to web_user, anonymous, admin;
grant select, insert on moment_service.moments to web_user, anonymous, admin;


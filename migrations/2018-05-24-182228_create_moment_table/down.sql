-- This file should undo anything in `up.sql`
drop function moment_service_api.track(jsonb);
drop table moment_service.moments;
-- This file should undo anything in `up.sql`
revoke usage on schema moment_service_api from postgrest, web_user, admin, anonymous;
revoke insert, select on moment_service.moments from postgrest, web_user, admin, anonymous;
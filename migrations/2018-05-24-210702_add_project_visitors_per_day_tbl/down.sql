-- This file should undo anything in `up.sql`
DROP FUNCTION moment_service.moments_projectid_from_label(label text);
DROP FUNCTION moment_service.moments_project_identifier_from_label(label text);
DROP TABLE moment_service.moments_navigation_projects_tbl;
DROP FUNCTION moment_service.moments_navigation_projects_tbl_refresh();
drop VIEW moment_service_api.project_visitors_per_day;
drop FUNCTION moment_service.project_visitors_per_day_tbl_refresh();
drop TABLE moment_service.project_visitors_per_day_tbl;
DROP FUNCTION public.zone_timestamp(timestamp without time zone);
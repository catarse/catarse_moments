-- This file should undo anything in `up.sql`
CREATE OR REPLACE FUNCTION moment_service.moments_projectid_from_label(label text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
	identifier text := moment_service.moments_project_identifier_from_label(label);
BEGIN
	IF identifier is null or identifier ~ '^d+$'
		THEN RETURN identifier::integer;
	END IF;

    RETURN (SELECT p.id
            FROM projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
EXCEPTION
WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
	RETURN (SELECT p.id
            FROM projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
END
$function$;

CREATE OR REPLACE FUNCTION moment_service.moments_project_identifier_from_label(label text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT
	CASE
		WHEN label ~ '^(/(en|pt))?/projects/(\d+)($|/.*)'
		THEN regexp_replace(label,'^(/(en|pt))?/projects/(\d+)($|/.*)', '\3')
	ELSE
	CASE
		WHEN label !~* '^/((en|pt)/)?($|\?|\#|((login|explore|sign_up|start|users|projects|flexible_projects)(/|$|\?|\#)))'
		THEN lower(regexp_replace(regexp_replace(label, '^/((en|pt)/)?', ''), '[/\?\#].*', ''))
	ELSE NULL::text
	END END
$function$
;
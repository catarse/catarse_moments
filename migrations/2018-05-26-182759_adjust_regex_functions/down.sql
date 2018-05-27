-- This file should undo anything in `up.sql`
CREATE OR REPLACE FUNCTION moment_service.moments_navigation_projects_tbl_refresh()
 RETURNS void
 LANGUAGE sql
AS $function$

INSERT into moment_service.moments_navigation_projects_tbl
 SELECT moments.id,
    moments.created_at,
    moments.data ->> 'ctrse_sid' AS ctrse_sid,
    (moments.data -> 'ga') ->> 'clientId' AS ga_client_id,
    ((moments.data -> 'user') ->> 'id')::integer AS user_id,
    COALESCE(
		((moments.data -> 'project') ->> 'id')::integer,
         moment_service.moments_projectid_from_label((moments.data ->> 'label'))
	) AS project_id,
    moments.data ->> 'action' AS action,
    lower(moments.data ->> 'label') AS label,
    moments.data ->> 'value' AS value,
        CASE
            WHEN (moments.data ->> 'label') = ANY (ARRAY['/', '/en', '/pt']) THEN '/'
            ELSE regexp_replace(lower(moments.data ->> 'label'), '(^/(pt|en))|(/$)', '')
        END AS path,
    regexp_replace((moments.data -> 'request') ->> 'domain', 'https?://([^/?#]+).*', '') AS req_domain,
    regexp_replace((moments.data -> 'request') ->> 'referrer', 'https?://([^/?#]+).*', '') AS req_referrer_domain,
    (moments.data -> 'request') ->> 'pathname' AS req_pathname,
    (moments.data -> 'request') ->> 'referrer' AS req_referrer,
    ((moments.data -> 'request') -> 'query') ->> 'campaign' AS req_campaign,
    ((moments.data -> 'request') -> 'query') ->> 'source' AS req_source,
    ((moments.data -> 'request') -> 'query') ->> 'medium' AS req_medium,
    ((moments.data -> 'request') -> 'query') ->> 'content' AS req_content,
    ((moments.data -> 'request') -> 'query') ->> 'term' AS req_term,
    ((moments.data -> 'request') -> 'query') ->> 'ref' AS req_ref,
    (moments.data -> 'origin') ->> 'domain' AS origin_domain,
    (moments.data -> 'origin') ->> 'referrer' AS origin_referrer,
    (moments.data -> 'origin') ->> 'campaign' AS origin_campaign,
    (moments.data -> 'origin') ->> 'source' AS origin_source,
    (moments.data -> 'origin') ->> 'medium' AS origin_medium,
    (moments.data -> 'origin') ->> 'content' AS origin_content,
    (moments.data -> 'origin') ->> 'term' AS origin_term,
    (moments.data -> 'origin') ->> 'ref' AS origin_ref,
    moments.data ->> 'request' AS request,
    moments.data ->> 'origin' AS origin
   FROM moment_service.moments as moments
  WHERE (moments.data ->> 'category') = 'navigation'
    AND moment_service.moments_project_identifier_from_label((moments.data ->> 'label')) is not null
	AND moments.created_at > coalesce((select max(created_at) from moment_service.moments_navigation_projects_tbl),'20100101')
  ORDER BY moments.created_at;
$function$;

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
            FROM catarse.projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
EXCEPTION
WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
	RETURN (SELECT p.id
            FROM catarse.projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
END
$function$
;
-- Your SQL goes here
create schema catarse_cache;

create materialized view catarse_cache.projects as
    select * from catarse.projects
    with no data;

create materialized view catarse_cache.project_transitions as
    select * from catarse.project_transitions
    with no data;

create unique index cache_projects_id_uidx on catarse_cache.projects(id);
create unique index cache_project_transitions_id_uidx on catarse_cache.project_transitions(id);



CREATE OR REPLACE FUNCTION moment_service.moments_projectid_from_label(label text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
	identifier text := moment_service.moments_project_identifier_from_label(label);
BEGIN
	IF identifier is null or identifier ~ '^\d+$'
		THEN RETURN identifier::integer;
	END IF;

    RETURN (SELECT p.id
            FROM catarse_cache.projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
EXCEPTION
WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
	RETURN (SELECT p.id
            FROM catarse_cache.projects p
            WHERE lower(p.permalink) = identifier
            LIMIT 1)::integer;
END
$function$;

CREATE OR REPLACE FUNCTION moment_service.moments_navigation_projects_tbl_refresh()
 RETURNS void
 LANGUAGE sql
AS $function$
refresh materialized view concurrently catarse_cache.projects;
refresh materialized view concurrently catarse_cache.project_transitions;

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
    regexp_replace((moments.data -> 'request') ->> 'domain', 'https?:\/\/([^\/\?#]+).*', '\1') AS req_domain,
    regexp_replace((moments.data -> 'request') ->> 'referrer', 'https?:\/\/([^\/\?#]+).*', '\1') AS req_referrer_domain,
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
  ORDER BY moments.created_at

$function$;
CREATE OR REPLACE FUNCTION moment_service.project_visitors_per_day_tbl_refresh()
 RETURNS void
 LANGUAGE sql
AS $function$
SELECT moment_service.moments_navigation_projects_tbl_refresh();

--Apaga as entradas de hoje.  Na 9.5 pode trocar pelo UPSET
DELETE FROM moment_service.project_visitors_per_day_tbl 
WHERE day >= to_char(zone_timestamp(CURRENT_TIMESTAMP::timestamp without time zone), 'YYYY-MM-DD');

INSERT into moment_service.project_visitors_per_day_tbl
    (SELECT n.project_id,
            to_char(zone_timestamp(n.created_at), 'YYYY-MM-DD') AS day,
            count(DISTINCT n.ctrse_sid) AS visitors
           FROM moment_service.moments_navigation_projects_tbl n
             JOIN catarse_cache.projects p ON p.id = n.project_id
             JOIN catarse_cache.project_transitions pt ON pt.project_id = p.id AND pt.to_state = 'online'
             LEFT JOIN LATERAL ( SELECT ptf_1.id,
                    ptf_1.created_at
                   FROM catarse_cache.project_transitions ptf_1
                  WHERE ptf_1.project_id = p.id AND (ptf_1.to_state = ANY (ARRAY['waiting_funds'::character varying, 'successful'::character varying, 'failed'::character varying]::text[]))
                  ORDER BY ptf_1.created_at
                 LIMIT 1) ptf ON true
          WHERE n.created_at >= pt.created_at 
			AND (ptf.* IS NULL OR n.created_at <= ptf.created_at)
			AND (n.user_id IS NULL OR n.user_id <> p.user_id)
			AND n.path !~ '^/projects/d+/.+'
			AND to_char(zone_timestamp(n.created_at), 'YYYY-MM-DD') > coalesce((select max(day) from moment_service.project_visitors_per_day_tbl),'20100101')
          GROUP BY n.project_id, day
          ORDER BY n.project_id, day)
--  só no PGSQL 9.5
--ON CONFLICT (project_id, day) DO UPDATE SET visitors = EXCLUDED.visitors
;

$function$;


CREATE UNIQUE INDEX cache_project_permalink_uidx ON catarse_cache.projects(lower(permalink));
CREATE INDEX online_projects_id_ix ON catarse_cache.projects(id) WHERE state::text = 'online'::text;
CREATE UNIQUE INDEX index_project_transitions_parent_sort ON catarse_cache.project_transitions (project_id,sort_key);
CREATE INDEX project_transitions_project_id_idx ON catarse_cache.project_transitions (project_id) WHERE most_recent;
CREATE INDEX project_transitions_project_id_to_state_created_at_idx on catarse_cache.project_transitions (project_id,to_state,created_at);
CREATE INDEX to_state_project_tran_idx on catarse_cache.project_transitions (to_state);
create index path_idx_moments_navigations_tbl on moment_service.moments_navigation_projects_tbl(path) where path !~ '^/projects/d+/.+';
create index path_created_at_idx_moments_navigations_tbl on moment_service.moments_navigation_projects_tbl(path, created_at);
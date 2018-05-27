-- Your SQL goes here
CREATE OR REPLACE FUNCTION moment_service.project_visitors_per_day_tbl_refresh()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
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
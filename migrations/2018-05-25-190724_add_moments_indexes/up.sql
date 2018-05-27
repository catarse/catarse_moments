-- Your SQL goes here
CREATE INDEX moments_category_action_idx ON moment_service.moments USING btree (((data ->> 'category'::text)), ((data ->> 'action'::text)));
CREATE INDEX moments_category_action_sid_created_idx ON moment_service.moments USING btree (created_at, ((data ->> 'ctrse_sid'::text)), ((data ->> 'action'::text)), ((data ->> 'category'::text)), ((data ->> 'label'::text)));
CREATE INDEX moments_created_at_idx ON moment_service.moments USING btree (created_at);
CREATE INDEX moments_created_project_user_category_action_idx1 ON moment_service.moments USING btree (created_at, (((data -> 'project'::text) ->> 'id'::text)), (((data -> 'user'::text) ->> 'id'::text)), ((data ->> 'category'::text)), ((data ->> 'action'::text)));
CREATE INDEX moments_month_userid_idx ON moment_service.moments USING btree (date_part('year'::text, created_at), date_part('month'::text, created_at), (((data -> 'user'::text) ->> 'id'::text)));
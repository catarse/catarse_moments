# frozen_string_literal: true

# run with .pgpass file and command:
# DB_USER=dbuser DB_NAME=dnmame DB_HOST=localhost

set :job_template, nil
set :output, { standard: '~/cron_metrics.log', error: '~/cron_metrics.log' }

def generate_psql_c(view)
  only_view = view.split('.')[1]
  parsed_name = view.start_with?('"') ? view.inspect : view
  %{ echo "DO language plpgsql \\$\\$BEGIN
  RAISE NOTICE 'begin updating #{parsed_name} %1',now();
  IF NOT EXISTS (SELECT true FROM pg_stat_activity WHERE pg_backend_pid() <> pid AND query ~* 'refresh materialized .*#{only_view}') THEN
     RAISE NOTICE 'refreshing view #{parsed_name} %1',now();
     REFRESH MATERIALIZED VIEW CONCURRENTLY #{parsed_name};
    RAISE NOTICE 'view refreshed #{parsed_name} %1',now();
  END IF;
 END\\$\\$;" | psql -U #{ENV['DB_USER']} -h #{ENV['DB_HOST']} -d #{ENV['DB_NAME']}
}
end

def generate_psql_function(function)
  %{ echo "DO language plpgsql \\$\\$BEGIN
      RAISE NOTICE 'begin updating #{function}() %1',now();
      IF NOT EXISTS (SELECT true FROM pg_stat_activity WHERE pg_backend_pid() <> pid AND query ~* '#{function}') THEN
        RAISE NOTICE 'running function #{function}() %1',now();
          PERFORM #{function}();
        RAISE NOTICE 'function runned #{function}() %1',now();
      END IF;
      END\\$\\$;" | psql -U #{ENV['DB_USER']} -h #{ENV['DB_HOST']} -d #{ENV['DB_NAME']}
  }
end

%w[
   moment_service.project_visitors_per_day_tbl_refresh
].each do |v|
  every 1.hour do
    command generate_psql_function(v)
  end
end



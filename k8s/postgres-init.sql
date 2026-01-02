-- Postgres initialization script for Datadog DBM
-- This script enables required extensions and sets up the datadog monitoring user

-- Enable pg_stat_statements extension (required for DBM)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create datadog monitoring user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'datadog') THEN
    CREATE USER datadog WITH PASSWORD 'datadog_password';
  END IF;
END
$$;

-- Grant necessary permissions for DBM
GRANT pg_monitor TO datadog;
GRANT SELECT ON pg_stat_database TO datadog;

-- Allow datadog user to connect to all databases
GRANT CONNECT ON DATABASE postgres TO datadog;

-- Create datadog schema for DBM functions
CREATE SCHEMA IF NOT EXISTS datadog;
GRANT USAGE ON SCHEMA datadog TO datadog;

-- Create explain_statement function for query plan analysis
CREATE OR REPLACE FUNCTION datadog.explain_statement(
  query text,
  OUT explain text
)
RETURNS SETOF text AS $$
BEGIN
  RETURN QUERY EXECUTE 'EXPLAIN (VERBOSE, FORMAT JSON) ' || query;
END;
$$ LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp;

-- Grant execute permission to datadog user
GRANT EXECUTE ON FUNCTION datadog.explain_statement(text) TO datadog;

-- Create function to grant read-only access on existing tables
CREATE OR REPLACE FUNCTION grant_dd_read_only()
RETURNS void AS $$
BEGIN
  EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO datadog';
  EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datadog';
END;
$$ LANGUAGE plpgsql;

-- Execute the function
SELECT grant_dd_read_only();

\echo 'Datadog DBM setup complete!'



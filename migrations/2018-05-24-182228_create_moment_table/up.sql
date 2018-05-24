-- Your SQL goes here
CREATE TABLE moment_service.moments (
    id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    data jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT action_not_null CHECK (((data ->> 'action'::text) IS NOT NULL))
);


CREATE FUNCTION moment_service_api.track(event jsonb) RETURNS moment_service.moments
LANGUAGE plpgsql
AS $$
DECLARE
v_moment moment_service.moments;
BEGIN
    INSERT INTO moment_service.moments(data) VALUES (event) RETURNING * INTO v_moment;

    RETURN v_moment;
END;
$$;

CREATE SEQUENCE moment_service.moments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE moment_service.moments_id_seq OWNED BY moment_service.moments.id;